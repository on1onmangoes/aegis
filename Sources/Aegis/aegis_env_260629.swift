// aegis_env_260629.swift
// Added 260629: Robust key resolution so the app works whether launched from Xcode,
// `swift run`, or a Finder double-click — none of which reliably inherit shell env.
// Order: (1) process environment, (2) a .env file discovered on disk. Still FAILS LOUDLY
// upstream (CerebrasClient) if the key is found nowhere — this is config sourcing, not
// error-masking fallback.
import Foundation

enum AegisEnv {
    private static var cache: [String: String] = [:]
    private static var loaded = false

    static func value(for key: String) -> String? {
        if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return v }
        if !loaded { loadDotEnvFiles() }
        return cache[key]
    }

    private static func loadDotEnvFiles() {
        loaded = true
        let fm = FileManager.default
        var candidates: [String] = []

        // 1) Walk up from the current working directory (covers `swift run`).
        var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<6 {
            candidates.append(dir.appendingPathComponent(".env_260629").path)
            candidates.append(dir.appendingPathComponent(".env.local").path)
            dir.deleteLastPathComponent()
        }
        // 2) Walk up from the executable location (covers Xcode/DerivedData & Finder).
        var exe = URL(fileURLWithPath: CommandLine.arguments.first ?? "/").deletingLastPathComponent()
        for _ in 0..<10 {
            candidates.append(exe.appendingPathComponent(".env_260629").path)
            exe.deleteLastPathComponent()
        }
        // 3) Known absolute locations on this machine (last resort for the demo).
        candidates.append("/Users/amitlamba/mangoes2/mangoes25831/tnkrbll 260327/Aegis_260629/.env_260629")
        candidates.append("/Users/amitlamba/mangoes2/mangoes25831/tnkrbll 260327/agent-starter-swift/VoiceAgentRAG/.env.local")

        for path in candidates {
            guard fm.fileExists(atPath: path),
                  let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            parse(content)
            if cache["CEREBRAS_API_KEY"] != nil {
                AegisLog.info("[ENV] loaded credentials from \(path)")
                return
            }
        }
        AegisLog.failure("AegisEnv.loadDotEnvFiles", "NoEnvFile",
                         "no .env file with CEREBRAS_API_KEY found in \(candidates.count) candidate paths")
    }

    private static func parse(_ content: String) {
        for raw in content.split(separator: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst("export ".count)) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let k = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var v = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if v.count >= 2, v.hasPrefix("\""), v.hasSuffix("\"") { v = String(v.dropFirst().dropLast()) }
            if !k.isEmpty { cache[k] = v }
        }
    }
}
