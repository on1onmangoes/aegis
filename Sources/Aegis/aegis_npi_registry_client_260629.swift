// aegis_npi_registry_client_260629.swift
// Added 260629: NPI Registry client (https://npiregistry.cms.hhs.gov/api/, version 2.1).
// Public CMS data, no API key. This is the AUTHORITATIVE verification source.
//   - If the extracted card carries an NPI number -> exact lookup by number.
//   - Otherwise -> name + state search (input-driven branch, NOT an error fallback).
// Fails loudly with AegisError.npiNotFound when no record matches.
import Foundation

enum NPIRegistryClient {
    private static let base = "https://npiregistry.cms.hhs.gov/api/"

    static func verify(_ cred: ExtractedCredential) async throws -> NPIResult {
        AegisLog.entry("NPIRegistryClient.verify",
                       "npi=\(cred.npi.isEmpty ? "none" : "present") state=\(cred.state)")

        var items = [URLQueryItem(name: "version", value: "2.1"),
                     URLQueryItem(name: "limit", value: "5")]

        let npiDigits = cred.npi.filter(\.isNumber)
        if npiDigits.count == 10 {
            items.append(URLQueryItem(name: "number", value: npiDigits))
        } else {
            // Name + state search. Derive first/last from the extracted full name.
            let parts = cred.name
                .replacingOccurrences(of: ",", with: " ")
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty && $0.uppercased() != $0.lowercased() }
            guard let last = parts.last, parts.count >= 1 else {
                throw AegisError.npiNotFound("no NPI number and unparseable name '\(cred.name)'")
            }
            if let first = parts.first, parts.count >= 2 {
                items.append(URLQueryItem(name: "first_name", value: first))
            }
            items.append(URLQueryItem(name: "last_name", value: last))
            if !cred.state.isEmpty {
                items.append(URLQueryItem(name: "state", value: cred.state))
            }
        }

        var comps = URLComponents(string: base)!
        comps.queryItems = items
        guard let url = comps.url else {
            throw AegisError.npiNotFound("could not build NPI query URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            AegisLog.failure("NPIRegistryClient.verify", "HTTP\(code)", "NPI registry request failed")
            throw AegisError.httpError(code, "NPI registry request failed")
        }

        let envelope: NPIEnvelope
        do {
            envelope = try JSONDecoder().decode(NPIEnvelope.self, from: data)
        } catch {
            throw AegisError.decodingFailed("NPI: \(error)")
        }

        guard let first = envelope.results?.first else {
            throw AegisError.npiNotFound("0 results for '\(cred.name)'")
        }
        AegisLog.info("[NPI] matched number=\(first.number) status=\(first.basic.status ?? "?")")
        return first
    }
}
