// aegis_youtube_client_260629.swift
// Added 260629: REAL YouTube data via the official YouTube Data API v3 (search.list).
// Replaces the earlier Brave web-search hack — YouTube has nothing to do with Brave.
// Reads YOUTUBE_API_KEY from .env. No key -> returns [] (no fabricated videos).
import Foundation

enum YouTubeClient {
    private static let endpoint = "https://www.googleapis.com/youtube/v3/search"

    static func videos(for truth: NPIResult, limit: Int = 4) async throws -> [RelatedVideo] {
        guard let key = AegisEnv.value(for: "YOUTUBE_API_KEY"), !key.isEmpty else {
            AegisLog.info("[YOUTUBE] no YOUTUBE_API_KEY — skipping video search")
            return []
        }
        let name = [truth.basic.first_name, truth.basic.last_name].compactMap { $0 }.joined(separator: " ")
        let specialty = truth.primaryTaxonomy?.desc ?? ""
        let q = "\(name) \(specialty)".trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        AegisLog.entry("YouTubeClient.videos", "q=\(q)")

        var c = URLComponents(string: endpoint)!
        c.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "q", value: q),
            .init(name: "type", value: "video"),
            .init(name: "maxResults", value: String(limit)),
            .init(name: "key", value: key)
        ]
        let (data, resp) = try await URLSession.shared.data(from: c.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            AegisLog.info("[YOUTUBE] HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            return []
        }
        guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = j["items"] as? [[String: Any]] else { return [] }

        var out: [RelatedVideo] = []
        for it in items {
            guard let idObj = it["id"] as? [String: Any], let vid = idObj["videoId"] as? String,
                  let sn = it["snippet"] as? [String: Any], let rawTitle = sn["title"] as? String else { continue }
            let title = rawTitle
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
            out.append(RelatedVideo(title: title, url: "https://www.youtube.com/watch?v=\(vid)", source: "YouTube"))
        }
        AegisLog.info("[YOUTUBE] \(out.count) videos for \(q)")
        return out
    }
}
