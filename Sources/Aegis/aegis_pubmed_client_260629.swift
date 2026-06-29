// aegis_pubmed_client_260629.swift
// Added 260629: PubMed E-utilities client (NCBI eutils, free, no key) for medical articles
// authored by the provider. esearch (author term) -> esummary (titles/journal/year).
// Real PMIDs only — never fabricated. Author-name match, so labelled "author match" (a
// common name may surface near-matches; honest by design, CLAUDE.md no pattern matching).
import Foundation

enum PubMedClient {
    private static let esearch = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
    private static let esummary = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"

    static func articles(for truth: NPIResult, limit: Int = 4) async throws -> [Publication] {
        let last = (truth.basic.last_name ?? "").trimmingCharacters(in: .whitespaces)
        let firstInitial = (truth.basic.first_name ?? "").first.map(String.init) ?? ""
        guard !last.isEmpty else { return [] }
        let term = "\(last) \(firstInitial)[Author]"
        AegisLog.entry("PubMedClient.articles", "term=\(term)")

        // 1) esearch -> PMIDs (most recent first)
        var c1 = URLComponents(string: esearch)!
        c1.queryItems = [
            .init(name: "db", value: "pubmed"),
            .init(name: "term", value: term),
            .init(name: "retmode", value: "json"),
            .init(name: "retmax", value: String(limit)),
            .init(name: "sort", value: "date"),
            .init(name: "tool", value: "aegis"), .init(name: "email", value: "demo@aegis.local")
        ]
        let (d1, _) = try await URLSession.shared.data(from: c1.url!)
        guard let j1 = try JSONSerialization.jsonObject(with: d1) as? [String: Any],
              let er = j1["esearchresult"] as? [String: Any],
              let ids = er["idlist"] as? [String], !ids.isEmpty else {
            AegisLog.info("[PUBMED] 0 articles for \(term)")
            return []
        }

        // 2) esummary -> titles
        var c2 = URLComponents(string: esummary)!
        c2.queryItems = [
            .init(name: "db", value: "pubmed"),
            .init(name: "id", value: ids.joined(separator: ",")),
            .init(name: "retmode", value: "json"),
            .init(name: "tool", value: "aegis"), .init(name: "email", value: "demo@aegis.local")
        ]
        let (d2, _) = try await URLSession.shared.data(from: c2.url!)
        guard let j2 = try JSONSerialization.jsonObject(with: d2) as? [String: Any],
              let result = j2["result"] as? [String: Any] else { return [] }

        var pubs: [Publication] = []
        for id in ids {
            guard let rec = result[id] as? [String: Any] else { continue }
            let title = (rec["title"] as? String) ?? "Untitled"
            let journal = (rec["fulljournalname"] as? String) ?? (rec["source"] as? String) ?? ""
            let pubdate = (rec["pubdate"] as? String) ?? ""
            let year = String(pubdate.prefix(4))
            pubs.append(Publication(pmid: id, title: title, journal: journal, year: year))
        }
        AegisLog.info("[PUBMED] \(pubs.count) articles for \(term)")
        return pubs
    }
}
