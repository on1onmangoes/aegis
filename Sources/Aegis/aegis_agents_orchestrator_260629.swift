// aegis_agents_orchestrator_260629.swift
// Added 260629: The Multiverse. Coordinates the agent realms and assembles the graph.
//
//   Realm 1  Extractor  (gemma-4-31b, MULTIMODAL, strict JSON)  : badge image -> claims
//   Realm 2  NPI Registry (authoritative, public)               : verify claims
//   Realm 3  Analyst    (gemma-4-31b, REASONING, strict JSON)    : claims vs truth -> verdict
//   Realm 4  MapKit                                              : nearby wellness providers
//
// Realms 3 and 4 run in PARALLEL after the NPI truth lands - Cerebras speed makes the
// fan-out feel instant (the demo point). The graph is assembled DETERMINISTICALLY in Swift
// from authoritative data (we never let the model invent the graph structure).
import Foundation
import SwiftUI

@MainActor
final class AegisViewModel: ObservableObject {
    @Published var nsImage: NSImage?
    @Published var status: String = "Drop a provider ID badge to begin."
    @Published var isRunning = false
    @Published var errorMessage: String?

    @Published var extracted: ExtractedCredential?
    @Published var npi: NPIResult?
    @Published var verdict: AnalystVerdict?
    @Published var nearby: [WellnessProvider] = []
    @Published var matchCriteria = MatchCriteria()
    @Published var matches: [MatchResult] = []
    @Published var publications: [Publication] = []
    @Published var videos: [RelatedVideo] = []
    @Published var cmsProfile: CMSProfile?
    @Published var background: BackgroundProfile?
    @Published var graph: CredentialGraph?
    @Published var timings: [AgentTiming] = []

    private var imageDataURI: String?

    var aggregateTokensPerSec: Double {
        let tps = timings.map(\.tokensPerSec).filter { $0 > 0 }
        guard !tps.isEmpty else { return 0 }
        return tps.reduce(0, +) / Double(tps.count)
    }

    func setImage(_ image: NSImage) {
        self.nsImage = image
        self.imageDataURI = image.aegisJPEGDataURI(maxDimension: 1024, quality: 0.7)
        self.status = imageDataURI == nil ? "Could not read that image." : "Ready. Press Verify."
        // Reset prior run
        extracted = nil; npi = nil; verdict = nil; nearby = []; matches = []
        publications = []; videos = []; cmsProfile = nil; background = nil; graph = nil
        timings = []; errorMessage = nil
    }

    func run() async {
        guard !isRunning else { return }
        guard let dataURI = imageDataURI else {
            errorMessage = AegisError.imageEncodingFailed.localizedDescription
            return
        }
        isRunning = true
        errorMessage = nil
        timings = []
        let startedAt = Date()

        do {
            let client = try CerebrasClient()

            // ---- Realm 1: Extractor (multimodal) ----
            status = "Realm 1 - Extractor reading the badge (gemma-4-31b, multimodal)…"
            let cred = try await runExtractor(client, imageDataURI: dataURI)
            self.extracted = cred
            AegisLog.info("[EXTRACT] credential=\(cred.credential) state=\(cred.state) npi=\(cred.npi.isEmpty ? "?" : "present")")

            // ---- Realm 2: NPI Registry (authoritative) ----
            status = "Realm 2 - Cross-checking the NPI Registry…"
            let npiResult = try await NPIRegistryClient.verify(cred)
            self.npi = npiResult

            // ---- Realms 3 + 4 + enrichment in PARALLEL (the speed moment) ----
            status = "Realms 3 & 4 - Analyst + mapping + PubMed + videos in parallel…"
            async let verdictResult = runAnalyst(client, claims: cred, truth: npiResult)
            async let nearbyResult = runMapSearch(npiResult)
            async let pubsResult = runPubMed(npiResult)
            async let videosResult = runVideos(npiResult)
            async let cmsResult = runCMS(npiResult)

            let verdict = try await verdictResult
            let nearby = await nearbyResult   // map failures are non-fatal -> empty (see runMapSearch)
            let pubs = await pubsResult        // non-fatal
            let vids = await videosResult      // non-fatal (real YouTube Data API)
            let cms = await cmsResult          // non-fatal (med school + grad year)
            self.verdict = verdict
            self.nearby = nearby
            self.publications = pubs
            self.videos = vids
            self.cmsProfile = cms

            // ---- 4th agent: Background (gemma-4-31b) synthesizes a profile from REAL inputs ----
            if !pubs.isEmpty || cms != nil {
                status = "Agent 4 - Background synthesis (gemma-4-31b)…"
                if let bg = try? await runBackground(client, truth: npiResult, cms: cms, publications: pubs) {
                    self.background = bg
                }
            }

            // ---- Realm 5: Matcher (options ✕ criteria → ranked) ----
            // Depends on Realm 4's options, so it runs after the parallel block.
            var matchResults: [MatchResult] = []
            if !nearby.isEmpty {
                status = "Realm 5 - Matching options against criteria (gemma-4-31b reasoning)…"
                matchResults = try await runMatcher(client, options: nearby, truth: npiResult, criteria: matchCriteria)
                self.matches = matchResults
            }

            // ---- Assemble the World Tree (deterministic) ----
            self.graph = GraphBuilder.build(claims: cred, truth: npiResult, verdict: verdict,
                                            nearby: nearby, matches: matchResults,
                                            publications: pubs, videos: vids,
                                            cms: cms, background: self.background)

            let totalMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            switch verdict.status {
            case "verified":
                status = "✓ Verified in \(totalMs)ms (wall clock)."
            case "needs_attention":
                status = "⚠︎ Needs attention — see verdict. (\(totalMs)ms wall clock)"
            default:
                status = "✗ Not verified — see verdict. (\(totalMs)ms wall clock)"
            }
            AegisLog.latency("AegisViewModel.run", totalMs)
        } catch {
            let err = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            self.errorMessage = err
            self.status = "Failed."
            AegisLog.failure("AegisViewModel.run", "\(type(of: error))", err)
        }
        isRunning = false
    }

    // MARK: - Realm 1: Extractor

    private func runExtractor(_ client: CerebrasClient, imageDataURI: String) async throws -> ExtractedCredential {
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "credential", "license_no", "npi", "state", "specialty"],
            "properties": [
                "name":       ["type": "string"],
                "credential": ["type": "string"],
                "license_no": ["type": "string"],
                "npi":        ["type": "string"],
                "state":      ["type": "string"],
                "specialty":  ["type": "string"]
            ]
        ]
        let sys = """
        You are the Extractor agent for Aegis credential verification. Read the provider \
        ID badge / license card in the image and extract the fields exactly as printed. \
        Use an empty string for any field that is not visibly present. Do not guess or \
        invent values. 'npi' must be the 10-digit NPI if shown, else empty. 'state' is the \
        2-letter US state of licensure.
        """
        let messages: [[String: Any]] = [
            CerebrasClient.system(sys),
            CerebrasClient.userWithImage("Extract the credential fields from this badge.", imageDataURI: imageDataURI)
        ]
        let rf = CerebrasClient.jsonSchema(name: "extracted_credential", schema: schema)
        let (content, timing) = try await client.chat(agent: "Extractor", messages: messages, responseFormat: rf)
        timings.append(timing)

        guard let data = content.data(using: .utf8) else {
            throw AegisError.extractionFailed("non-utf8 content")
        }
        let cred = try JSONDecoder().decode(ExtractedCredential.self, from: data)
        if cred.isEmpty { throw AegisError.extractionFailed("no fields detected on the badge") }
        return cred
    }

    // MARK: - Realm 3: Analyst (reasoning)

    private func runAnalyst(_ client: CerebrasClient, claims: ExtractedCredential, truth: NPIResult) async throws -> AnalystVerdict {
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["status", "score", "discrepancies", "risk_flags", "summary"],
            "properties": [
                "status":        ["type": "string", "enum": ["verified", "needs_attention", "not_verified"]],
                "score":         ["type": "number"],
                "discrepancies": ["type": "array", "items": ["type": "string"]],
                "risk_flags":    ["type": "array", "items": ["type": "string"]],
                "summary":       ["type": "string"]
            ]
        ]
        let tax = truth.primaryTaxonomy
        let truthJSON = """
        {
          "npi": \(truth.number),
          "first_name": "\(truth.basic.first_name ?? "")",
          "last_name": "\(truth.basic.last_name ?? "")",
          "credential": "\(truth.basic.credential ?? "")",
          "status": "\(truth.basic.status ?? "")",
          "primary_specialty": "\(tax?.desc ?? "")",
          "license": "\(tax?.license ?? "")",
          "license_state": "\(tax?.state ?? "")"
        }
        """
        let sys = """
        You are the Analyst agent for Aegis. Compare the credential CLAIMS extracted from a \
        provider's badge against the AUTHORITATIVE NPI Registry record, and assign one of three \
        states plus a 0.0-1.0 trust score:
          • "verified" (score >= 0.8): identity, specialty, license and state are consistent, \
            and the NPI status is active. No material discrepancies.
          • "needs_attention" (score 0.4-0.79): mostly consistent but with gaps that warrant a \
            human check — e.g. missing/blank license, NPI status not active, partial name match, \
            or a near-miss specialty.
          • "not_verified" (score < 0.4): a material mismatch — wrong specialty, fabricated or \
            non-matching license/NPI, or other fraud indicators.
        List concrete discrepancies and risk flags. Be precise and conservative.
        """
        let usr = """
        CLAIMS (from badge):
        name="\(claims.name)", credential="\(claims.credential)", license_no="\(claims.license_no)", \
        npi="\(claims.npi)", state="\(claims.state)", specialty="\(claims.specialty)"

        AUTHORITATIVE NPI RECORD:
        \(truthJSON)

        Return the verdict.
        """
        let messages: [[String: Any]] = [CerebrasClient.system(sys), CerebrasClient.user(usr)]
        let rf = CerebrasClient.jsonSchema(name: "analyst_verdict", schema: schema)
        // reasoning_effort medium: turn Gemma 4 thinking on for the comparison.
        let (content, timing) = try await client.chat(agent: "Analyst", messages: messages,
                                                      responseFormat: rf, reasoningEffort: "medium")
        timings.append(timing)
        guard let data = content.data(using: .utf8) else {
            throw AegisError.extractionFailed("analyst non-utf8 content")
        }
        return try JSONDecoder().decode(AnalystVerdict.self, from: data)
    }

    // MARK: - Realm 5: Matcher (gemma-4-31b reasoning, strict JSON)

    private func runMatcher(_ client: CerebrasClient, options: [WellnessProvider],
                            truth: NPIResult, criteria: MatchCriteria) async throws -> [MatchResult] {
        // Options = the verified provider itself + the nearby providers. The Matcher may only
        // RANK these real options; it must never invent providers.
        let verifiedName = [truth.basic.first_name, truth.basic.last_name]
            .compactMap { $0 }.joined(separator: " ")
        let verifiedSpecialty = truth.primaryTaxonomy?.desc ?? "Unknown"

        var optionLines: [String] = []
        optionLines.append("- name=\"\(verifiedName)\", specialty=\"\(verifiedSpecialty)\", distance_km=0.0, source=\"verified (NPI)\"")
        for p in options {
            let km = p.distanceMeters.map { String(format: "%.1f", $0 / 1000) } ?? "unknown"
            optionLines.append("- name=\"\(p.name)\", specialty=\"unknown (directory listing)\", distance_km=\(km), source=\"nearby (MapKit)\"")
        }

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["matches"],
            "properties": [
                "matches": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["name", "score", "fits", "gaps", "reason"],
                        "properties": [
                            "name":   ["type": "string"],
                            "score":  ["type": "number"],
                            "fits":   ["type": "array", "items": ["type": "string"]],
                            "gaps":   ["type": "array", "items": ["type": "string"]],
                            "reason": ["type": "string"]
                        ]
                    ]
                ]
            ]
        ]
        let sys = """
        You are the Matcher agent for Aegis. You are given a fixed list of REAL provider OPTIONS \
        and a patient's CRITERIA. Score each option from 0.0 to 1.0 on how well it fits the \
        criteria, considering specialty (treat near-synonyms as matches, e.g. 'Child Psychiatry' \
        ≈ 'Psychiatry, Child & Adolescent'), distance vs the max, and the other criteria. List \
        what fits and what gaps remain, and give a one-line reason. Rank from best to worst. \
        CRITICAL: only score options from the provided list — never invent a provider. Return \
        every option exactly once.
        """
        let usr = """
        CRITERIA:
        needed_specialty="\(criteria.neededSpecialty)", max_distance_km=\(criteria.maxDistanceKm), \
        must_accept_new_patients=\(criteria.mustAcceptNewPatients), modality="\(criteria.modality)"

        OPTIONS:
        \(optionLines.joined(separator: "\n"))

        Return the ranked matches.
        """
        let messages: [[String: Any]] = [CerebrasClient.system(sys), CerebrasClient.user(usr)]
        let rf = CerebrasClient.jsonSchema(name: "match_results", schema: schema)
        let (content, timing) = try await client.chat(agent: "Matcher", messages: messages,
                                                      responseFormat: rf, reasoningEffort: "medium")
        timings.append(timing)
        guard let data = content.data(using: .utf8) else {
            throw AegisError.extractionFailed("matcher non-utf8 content")
        }
        let envelope = try JSONDecoder().decode(MatchEnvelope.self, from: data)
        return envelope.matches.sorted { $0.score > $1.score }
    }

    // MARK: - Realm 4: MapKit (nearby providers; non-fatal)

    private func runMapSearch(_ truth: NPIResult) async -> [WellnessProvider] {
        guard let addr = truth.locationAddress?.oneLine, !addr.isEmpty else { return [] }
        do {
            return try await MapSearch.nearbyWellnessProviders(address: addr)
        } catch {
            // Non-fatal: the area map enriches the graph but is not required for verification.
            AegisLog.failure("AegisViewModel.runMapSearch", "\(type(of: error))",
                             (error as? LocalizedError)?.errorDescription ?? "\(error)")
            return []
        }
    }

    // MARK: - Enrichment: PubMed articles + related videos (non-fatal)

    private func runPubMed(_ truth: NPIResult) async -> [Publication] {
        do { return try await PubMedClient.articles(for: truth) }
        catch {
            AegisLog.failure("AegisViewModel.runPubMed", "\(type(of: error))",
                             (error as? LocalizedError)?.errorDescription ?? "\(error)")
            return []
        }
    }

    private func runVideos(_ truth: NPIResult) async -> [RelatedVideo] {
        do { return try await YouTubeClient.videos(for: truth) }
        catch {
            AegisLog.failure("AegisViewModel.runVideos", "\(type(of: error))",
                             (error as? LocalizedError)?.errorDescription ?? "\(error)")
            return []
        }
    }

    private func runCMS(_ truth: NPIResult) async -> CMSProfile? {
        do { return try await CMSClient.profile(for: truth.number) }
        catch {
            AegisLog.failure("AegisViewModel.runCMS", "\(type(of: error))",
                             (error as? LocalizedError)?.errorDescription ?? "\(error)")
            return nil
        }
    }

    // MARK: - Agent 4: Background (gemma-4-31b, strict JSON) — synthesizes from REAL inputs only

    private func runBackground(_ client: CerebrasClient, truth: NPIResult,
                               cms: CMSProfile?, publications: [Publication]) async throws -> BackgroundProfile {
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["summary", "focus_areas"],
            "properties": [
                "summary":     ["type": "string"],
                "focus_areas": ["type": "array", "items": ["type": "string"]]
            ]
        ]
        let specialty = truth.primaryTaxonomy?.desc ?? "Unknown"
        let medLine = cms.map { "Medical school: \($0.medSchool), graduated \($0.gradYear)." } ?? "Medical school: not on file."
        let paperLines = publications.prefix(4).map { "- \($0.title) (\($0.journal) \($0.year))" }.joined(separator: "\n")
        let sys = """
        You are the Background agent for Aegis. Using ONLY the facts provided (specialty, \
        medical school, and the titles of the provider's own publications), write a concise \
        2-sentence professional background and list 2-4 research/clinical focus areas inferred \
        strictly from the paper titles. Do NOT invent training, affiliations, awards, residency, \
        or anything not present in the inputs.
        """
        let usr = """
        Specialty: \(specialty)
        \(medLine)
        Publications:
        \(paperLines.isEmpty ? "(none provided)" : paperLines)
        """
        let messages: [[String: Any]] = [CerebrasClient.system(sys), CerebrasClient.user(usr)]
        let rf = CerebrasClient.jsonSchema(name: "background_profile", schema: schema)
        let (content, timing) = try await client.chat(agent: "Background", messages: messages,
                                                      responseFormat: rf, reasoningEffort: "low")
        timings.append(timing)
        guard let data = content.data(using: .utf8) else {
            throw AegisError.extractionFailed("background non-utf8 content")
        }
        return try JSONDecoder().decode(BackgroundProfile.self, from: data)
    }
}

// MARK: - Deterministic graph assembly

enum GraphBuilder {
    static func build(claims: ExtractedCredential, truth: NPIResult,
                      verdict: AnalystVerdict, nearby: [WellnessProvider],
                      matches: [MatchResult] = [],
                      publications: [Publication] = [], videos: [RelatedVideo] = [],
                      cms: CMSProfile? = nil, background: BackgroundProfile? = nil) -> CredentialGraph {
        // Score lookup so provider nodes can show their match score + highlight the top fit.
        let scoreByName = Dictionary(matches.map { ($0.name, $0.score) }, uniquingKeysWith: { a, _ in a })
        let topMatchName = matches.first?.name
        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []

        let personName = [truth.basic.first_name, truth.basic.last_name]
            .compactMap { $0 }.joined(separator: " ")
            .ifEmpty(claims.name)
        let active = (truth.basic.status ?? "").uppercased() == "A"

        // Center: the person (3-state status from the Analyst agent)
        nodes.append(GraphNode(id: "person", label: personName, kind: .person,
                               detail: "Identity: \(verdict.displayLabel)",
                               verified: verdict.isVerified, attention: verdict.needsAttention))

        // Verdict node (green = verified, amber = needs attention, red = not verified)
        nodes.append(GraphNode(id: "verdict", label: verdict.displayLabel, kind: .verdict,
                               detail: "score \(Int(verdict.score * 100))% — \(verdict.summary)",
                               verified: verdict.isVerified, attention: verdict.needsAttention))
        edges.append(GraphEdge(from: "person", to: "verdict", label: "verdict"))

        // Claimed credential (from the card)
        nodes.append(GraphNode(id: "claimed", label: claims.credential.ifEmpty("(no credential)"),
                               kind: .claimed, detail: "Claimed on badge", verified: false))
        edges.append(GraphEdge(from: "person", to: "claimed", label: "claims"))

        // Authoritative NPI
        nodes.append(GraphNode(id: "npi", label: "NPI \(truth.number)", kind: .npi,
                               detail: active ? "Active (CMS NPI Registry)" : "Status: \(truth.basic.status ?? "?")",
                               verified: active))
        edges.append(GraphEdge(from: "person", to: "npi", label: "verified"))

        if let tax = truth.primaryTaxonomy {
            if let desc = tax.desc, !desc.isEmpty {
                nodes.append(GraphNode(id: "specialty", label: desc, kind: .specialty,
                                       detail: "Primary taxonomy", verified: true))
                edges.append(GraphEdge(from: "npi", to: "specialty", label: "specialty"))
            }
            if let lic = tax.license, !lic.isEmpty {
                let stateSuffix = tax.state.map { " (\($0))" } ?? ""
                nodes.append(GraphNode(id: "license", label: "License \(lic)\(stateSuffix)",
                                       kind: .license, detail: "State board record", verified: true))
                edges.append(GraphEdge(from: "npi", to: "license", label: "licensed"))
            }
        }

        if let addr = truth.locationAddress?.oneLine, !addr.isEmpty {
            nodes.append(GraphNode(id: "address", label: addr, kind: .address,
                                   detail: "Practice location", verified: true))
            edges.append(GraphEdge(from: "npi", to: "address", label: "located at"))

            for (i, p) in nearby.enumerated() {
                let id = "provider_\(i)"
                let dist = p.distanceMeters.map { String(format: " · %.1f km", $0 / 1000) } ?? ""
                let isTop = (p.name == topMatchName)
                var detail = "Nearby wellness provider\(dist)"
                if let s = scoreByName[p.name] {
                    detail += String(format: " · match %.0f%%", s * 100)
                }
                if isTop { detail += " · TOP MATCH" }
                // Highlight the Matcher's best fit (verified=true → distinct node color).
                nodes.append(GraphNode(id: id, label: p.name, kind: .provider,
                                       detail: detail, verified: isTop))
                edges.append(GraphEdge(from: "address", to: id, label: isTop ? "best match" : "near"))
            }
        }

        // Education (CMS med school + grad year) — authoritative, off the person.
        if let cms = cms, !cms.medSchool.isEmpty {
            let yr = cms.gradYear.isEmpty ? "" : " · \(cms.gradYear)"
            nodes.append(GraphNode(id: "medschool", label: "\(cms.medSchool)\(yr)", kind: .education,
                                   detail: "Medical school (CMS)", verified: true))
            edges.append(GraphEdge(from: "person", to: "medschool", label: "trained at"))
            if !cms.residency.isEmpty {
                nodes.append(GraphNode(id: "residency", label: cms.residency, kind: .education,
                                       detail: "Residency", verified: true))
                edges.append(GraphEdge(from: "medschool", to: "residency", label: "residency"))
            }
            if !cms.undergrad.isEmpty {
                nodes.append(GraphNode(id: "undergrad", label: cms.undergrad, kind: .education,
                                       detail: "Undergraduate", verified: true))
                edges.append(GraphEdge(from: "medschool", to: "undergrad", label: "undergrad"))
            }
        }

        // Background (Agent 4) — focus areas inferred from real publications.
        if let bg = background, !bg.focus_areas.isEmpty {
            nodes.append(GraphNode(id: "background", label: "Focus areas", kind: .focus,
                                   detail: bg.summary, verified: false))
            edges.append(GraphEdge(from: "person", to: "background", label: "background"))
            for (i, f) in bg.focus_areas.prefix(4).enumerated() {
                let id = "focus_\(i)"
                nodes.append(GraphNode(id: id, label: f, kind: .focus, detail: "Inferred from publications", verified: false))
                edges.append(GraphEdge(from: "background", to: id, label: ""))
            }
        }

        // Medical articles (PubMed) — hub off the person, leaves under it.
        if !publications.isEmpty {
            nodes.append(GraphNode(id: "articles_hub", label: "Publications (\(publications.count))",
                                   kind: .article, detail: "PubMed author match", verified: false))
            edges.append(GraphEdge(from: "person", to: "articles_hub", label: "authored"))
            for (i, p) in publications.enumerated() {
                let id = "article_\(i)"
                let label = p.title.count > 42 ? String(p.title.prefix(42)) + "…" : p.title
                let detail = "\(p.journal) \(p.year)".trimmingCharacters(in: .whitespaces)
                nodes.append(GraphNode(id: id, label: label, kind: .article, detail: detail, verified: false))
                edges.append(GraphEdge(from: "articles_hub", to: id, label: ""))
            }
        }

        // Related videos (Brave → YouTube) — hub off the person, leaves under it.
        if !videos.isEmpty {
            nodes.append(GraphNode(id: "media_hub", label: "Media (\(videos.count))",
                                   kind: .video, detail: "Related videos", verified: false))
            edges.append(GraphEdge(from: "person", to: "media_hub", label: "media"))
            for (i, v) in videos.enumerated() {
                let id = "video_\(i)"
                let label = v.title.count > 42 ? String(v.title.prefix(42)) + "…" : v.title
                nodes.append(GraphNode(id: id, label: label, kind: .video, detail: v.source, verified: false))
                edges.append(GraphEdge(from: "media_hub", to: id, label: ""))
            }
        }

        return CredentialGraph(nodes: nodes, edges: edges)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
