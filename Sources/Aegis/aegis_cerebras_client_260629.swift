// aegis_cerebras_client_260629.swift
// Added 260629: OpenAI-compatible Cerebras Inference client for gemma-4-31b.
//   - Multimodal messages (text + base64 data-URI image), per hackathon FAQ:
//     only Base64 data URIs are supported, hosted image URLs are NOT.
//   - Structured Outputs via response_format json_schema strict:true
//   - reasoning_effort none/low/medium/high (off by default)
//   - Parses usage + time_info -> AgentTiming (tokens/sec, total latency) for the speed HUD
// NO FALLBACK CODE: rate limits / timeouts / non-2xx all throw a specific AegisError.
import Foundation

final class CerebrasClient {
    static let endpoint = URL(string: "https://api.cerebras.ai/v1/chat/completions")!
    static let defaultModel = "gemma-4-31b"

    private let apiKey: String
    private let session: URLSession

    init() throws {
        // Resolve from process env first, then a discovered .env file (Xcode/Finder safe).
        // Fail loudly if found nowhere.
        guard let key = AegisEnv.value(for: "CEREBRAS_API_KEY"),
              !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            AegisLog.failure("CerebrasClient.init", "MissingAPIKey",
                             "CEREBRAS_API_KEY not in environment or any .env file")
            throw AegisError.missingAPIKey("CEREBRAS_API_KEY")
        }
        self.apiKey = key
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30   // FAQ: fail, do not silently retry
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    // MARK: Message builders

    static func system(_ text: String) -> [String: Any] {
        ["role": "system", "content": text]
    }
    static func user(_ text: String) -> [String: Any] {
        ["role": "user", "content": text]
    }
    /// Multimodal user turn: text + one image as a base64 data URI (data:image/jpeg;base64,...).
    static func userWithImage(_ text: String, imageDataURI: String) -> [String: Any] {
        ["role": "user", "content": [
            ["type": "text", "text": text],
            ["type": "image_url", "image_url": ["url": imageDataURI]]
        ]]
    }
    /// Strict JSON-schema response_format (Structured Outputs).
    static func jsonSchema(name: String, schema: [String: Any]) -> [String: Any] {
        ["type": "json_schema", "json_schema": ["name": name, "strict": true, "schema": schema]]
    }

    // MARK: Core call

    func chat(agent: String,
              messages: [[String: Any]],
              model: String = CerebrasClient.defaultModel,
              responseFormat: [String: Any]? = nil,
              reasoningEffort: String? = nil) async throws -> (content: String, timing: AgentTiming) {

        AegisLog.entry("CerebrasClient.chat", "agent=\(agent) msgs=\(messages.count)")
        AegisLog.model(model, agent)

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "max_completion_tokens": 2048
        ]
        if let rf = responseFormat { body["response_format"] = rf }
        if let re = reasoningEffort { body["reasoning_effort"] = re }

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            AegisLog.failure("CerebrasClient.chat", "Transport", error.localizedDescription)
            throw AegisError.httpError(-1, error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AegisError.httpError(-1, "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? "<no body>"
            AegisLog.failure("CerebrasClient.chat", "HTTP\(http.statusCode)", txt)
            throw AegisError.httpError(http.statusCode, txt)   // includes 429 rate limit - caller decides
        }

        let decoded: CerebrasResponse
        do {
            decoded = try JSONDecoder().decode(CerebrasResponse.self, from: data)
        } catch {
            AegisLog.failure("CerebrasClient.chat", "Decoding", "\(error)")
            throw AegisError.decodingFailed("\(error)")
        }

        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AegisError.emptyModelResponse(agent)
        }

        let completionTokens = decoded.usage?.completion_tokens ?? 0
        let completionTime = decoded.time_info?.completion_time ?? 0
        let totalTime = decoded.time_info?.total_time ?? 0
        let tps = completionTime > 0 ? Double(completionTokens) / completionTime : 0
        let totalMs = Int((totalTime * 1000).rounded())

        let timing = AgentTiming(
            agent: agent,
            model: model,
            totalMs: totalMs,
            promptTokens: decoded.usage?.prompt_tokens ?? 0,
            completionTokens: completionTokens,
            tokensPerSec: tps
        )
        AegisLog.latency("CerebrasClient.chat[\(agent)]", totalMs)
        AegisLog.info("[SPEED] \(agent): \(String(format: "%.0f", tps)) tok/s, \(completionTokens) tok, \(totalMs)ms")
        return (content, timing)
    }
}

// MARK: - Response decoding (OpenAI-compatible + Cerebras time_info)

struct CerebrasResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let content: String? }
        let message: Message
    }
    struct Usage: Codable {
        let prompt_tokens: Int?
        let completion_tokens: Int?
        let total_tokens: Int?
    }
    struct TimeInfo: Codable {
        let queue_time: Double?
        let prompt_time: Double?
        let completion_time: Double?
        let total_time: Double?
    }
    let choices: [Choice]
    let usage: Usage?
    let time_info: TimeInfo?
}
