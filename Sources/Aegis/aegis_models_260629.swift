// aegis_models_260629.swift
// Added 260629: All Codable data contracts for Aegis.
//   - ExtractedCredential : strict-schema output of the multimodal Extractor agent
//   - AnalystVerdict      : strict-schema output of the Gemma reasoning Analyst agent
//   - NPIResult / NPIAddress / NPITaxonomy : NPI Registry API (free, public)
//   - WellnessProvider    : MapKit MKLocalSearch result
//   - GraphNode / GraphEdge / CredentialGraph : what the SwiftUI Canvas renders
//   - AgentTiming         : per-agent Cerebras speed metrics (tokens/sec, TTFT, total)
import Foundation

// MARK: - Extractor agent output (multimodal Gemma 4 31B, strict JSON schema)

struct ExtractedCredential: Codable, Equatable {
    var name: String
    var credential: String      // e.g. "MD", "PsyD", "LCSW"
    var license_no: String
    var npi: String
    var state: String
    var specialty: String

    var isEmpty: Bool {
        [name, credential, license_no, npi, state, specialty]
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Analyst agent output (Gemma 4 31B reasoning, strict JSON schema)

struct AnalystVerdict: Codable, Equatable {
    var status: String          // "verified" | "needs_attention" | "not_verified"
    var score: Double           // 0.0 - 1.0 trust score
    var discrepancies: [String]
    var risk_flags: [String]
    var summary: String

    var isVerified: Bool { status == "verified" }
    var needsAttention: Bool { status == "needs_attention" }
    var displayLabel: String {
        switch status {
        case "verified":        return "VERIFIED"
        case "needs_attention": return "NEEDS ATTENTION"
        default:                return "NOT VERIFIED"
        }
    }
}

// MARK: - NPI Registry (https://npiregistry.cms.hhs.gov/api/ - public, no key)

struct NPIEnvelope: Codable {
    let result_count: Int
    let results: [NPIResult]?
}

struct NPIResult: Codable, Equatable {
    let number: String          // NPI Registry returns this as a string, e.g. "1750725495"
    let basic: NPIBasic
    let taxonomies: [NPITaxonomy]?
    let addresses: [NPIAddress]?

    var primaryTaxonomy: NPITaxonomy? {
        taxonomies?.first(where: { $0.primary == true }) ?? taxonomies?.first
    }
    var locationAddress: NPIAddress? {
        addresses?.first(where: { $0.address_purpose == "LOCATION" }) ?? addresses?.first
    }
}

struct NPIBasic: Codable, Equatable {
    let first_name: String?
    let last_name: String?
    let credential: String?
    let status: String?         // "A" = active
    let name: String?           // present for organizations
}

struct NPITaxonomy: Codable, Equatable {
    let code: String?
    let desc: String?
    let primary: Bool?
    let state: String?
    let license: String?
}

struct NPIAddress: Codable, Equatable {
    let address_1: String?
    let address_2: String?
    let city: String?
    let state: String?
    let postal_code: String?
    let telephone_number: String?
    let address_purpose: String?

    var oneLine: String {
        [address_1, city, state, postal_code]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - MapKit nearby wellness providers

struct WellnessProvider: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    let distanceMeters: Double?
}

// MARK: - PubMed articles + related videos (graph enrichment)

struct Publication: Identifiable, Equatable {
    var id: String { pmid }
    let pmid: String
    let title: String
    let journal: String
    let year: String
    var url: String { "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/" }
}

struct RelatedVideo: Identifiable, Equatable {
    var id: String { url }
    let title: String
    let url: String
    let source: String          // "YouTube"
}

// CMS Doctors & Clinicians (med school + grad year). Residency/undergrad are NOT in any
// free authoritative source — left empty unless a real source is supplied (never fabricated).
struct CMSProfile: Equatable {
    let medSchool: String
    let gradYear: String
    let facility: String
    let residency: String       // populated only from a real source; "" otherwise
    let undergrad: String       // populated only from a real source; "" otherwise
}

// Output of the Background agent (4th Gemma agent) — synthesized from REAL inputs only.
struct BackgroundProfile: Codable, Equatable {
    var summary: String
    var focus_areas: [String]
}

// MARK: - Realm 5: Matcher (options ✕ criteria → ranked)

struct MatchCriteria: Equatable {
    var neededSpecialty: String = "Psychiatry"
    var maxDistanceKm: Double = 5
    var mustAcceptNewPatients: Bool = true
    var modality: String = "in-person"   // in-person / telehealth / either
}

struct MatchEnvelope: Codable {           // strict-schema root must be an object
    let matches: [MatchResult]
}

struct MatchResult: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let score: Double                     // 0.0 - 1.0
    let fits: [String]                    // criteria met
    let gaps: [String]                    // criteria missed
    let reason: String
}

// MARK: - Credential graph (rendered by aegis_graph_view_260629.swift)

enum GraphNodeKind: String, Codable {
    case person, claimed, npi, license, specialty, address, affiliation, provider, verdict, article, video, education, focus
}

struct GraphNode: Identifiable, Equatable {
    let id: String
    let label: String
    let kind: GraphNodeKind
    let detail: String
    let verified: Bool          // green if verified against an authoritative source
    var attention: Bool = false // amber: needs human review (the middle of the 3 states)
}

struct GraphEdge: Identifiable, Equatable {
    var id: String { "\(from)->\(to)" }
    let from: String
    let to: String
    let label: String           // "claims" / "verified" / "located at" / "near"
}

struct CredentialGraph: Equatable {
    var nodes: [GraphNode]
    var edges: [GraphEdge]
}

// MARK: - Per-agent Cerebras speed metrics (the demo HUD)

struct AgentTiming: Identifiable, Equatable {
    let id = UUID()
    let agent: String
    let model: String
    let totalMs: Int
    let promptTokens: Int
    let completionTokens: Int
    let tokensPerSec: Double
}
