// aegis_logging_260629.swift
// Added 260629: CLAUDE.md-compliant logging. Mandatory log points:
//   [ENTRY] [MODEL] [LATENCY] [FAILURE] [THRESHOLD]
// HIPAA-safe: never log patient names/DOB/SSN/raw image bytes. Log session_id,
// agent, model, confidence, timing only.
import Foundation

enum AegisLog {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func emit(_ level: String, _ message: String) {
        // Format mirrors CLAUDE.md: '%(asctime)s | %(levelname)s | %(name)s | %(message)s'
        print("\(iso.string(from: Date())) | \(level) | Aegis | \(message)")
    }

    static func entry(_ fn: String, _ sanitizedParams: String) {
        emit("INFO", "[ENTRY] \(fn) called with \(sanitizedParams)")
    }

    static func model(_ modelName: String, _ taskType: String) {
        emit("INFO", "[MODEL] Using \(modelName) for \(taskType)")
    }

    static func latency(_ fn: String, _ elapsedMs: Int) {
        emit("INFO", "[LATENCY] \(fn) completed in \(elapsedMs)ms")
    }

    static func failure(_ fn: String, _ errorType: String, _ errorMessage: String) {
        emit("ERROR", "[FAILURE] \(fn) failed: \(errorType) - \(errorMessage)")
    }

    static func threshold(_ metric: String, _ value: String, _ threshold: String) {
        emit("WARN", "[THRESHOLD] \(metric) at \(value), threshold is \(threshold)")
    }

    static func clinical(_ sessionId: String, _ alertType: String, _ confidence: Double) {
        emit("INFO", "[CLINICAL] session=\(sessionId) alert=\(alertType) confidence=\(String(format: "%.3f", confidence))")
    }

    static func info(_ message: String) { emit("INFO", message) }
}

// Added 260629: Fail-loudly error type. No fallback code anywhere - every failure
// surfaces a specific, named error to the caller / UI.
enum AegisError: LocalizedError {
    case missingAPIKey(String)
    case httpError(Int, String)
    case decodingFailed(String)
    case emptyModelResponse(String)
    case extractionFailed(String)
    case npiNotFound(String)
    case geocodeFailed(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let v):     return "Missing API key: \(v)"
        case .httpError(let c, let b):  return "HTTP \(c): \(b)"
        case .decodingFailed(let m):    return "Decoding failed: \(m)"
        case .emptyModelResponse(let m):return "Empty model response: \(m)"
        case .extractionFailed(let m):  return "Credential extraction failed: \(m)"
        case .npiNotFound(let m):       return "NPI not found: \(m)"
        case .geocodeFailed(let m):     return "Geocode failed: \(m)"
        case .imageEncodingFailed:      return "Could not encode the dropped image to base64."
        }
    }
}
