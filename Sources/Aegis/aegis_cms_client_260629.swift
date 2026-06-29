// aegis_cms_client_260629.swift
// Added 260629: CMS "Doctors and Clinicians" national file (data.cms.gov provider-data,
// dataset mj5m-pzi6). Free, authoritative. Provides MEDICAL SCHOOL + GRADUATION YEAR by NPI
// for Medicare-enrolled clinicians (partial coverage — returns nil when not enrolled).
// Residency + undergrad are NOT in this (or any free authoritative) source.
import Foundation

enum CMSClient {
    private static let dataset = "mj5m-pzi6"

    static func profile(for npi: String) async throws -> CMSProfile? {
        let digits = npi.filter(\.isNumber)
        guard digits.count == 10 else { return nil }
        AegisLog.entry("CMSClient.profile", "npi=present")

        var c = URLComponents(string: "https://data.cms.gov/provider-data/api/1/datastore/query/\(dataset)/0")!
        c.queryItems = [
            .init(name: "conditions[0][property]", value: "NPI"),
            .init(name: "conditions[0][operator]", value: "="),
            .init(name: "conditions[0][value]", value: digits),
            .init(name: "limit", value: "1")
        ]
        let (data, resp) = try await URLSession.shared.data(from: c.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            AegisLog.info("[CMS] HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            return nil
        }
        guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = j["results"] as? [[String: Any]], let row = results.first else {
            AegisLog.info("[CMS] no record for this NPI")
            return nil
        }
        let med = (row["med_sch"] as? String) ?? ""
        let yr = (row["grd_yr"] as? String) ?? ""
        let facility = (row["facility_name"] as? String) ?? ""
        guard !(med.isEmpty && yr.isEmpty) else { return nil }
        AegisLog.info("[CMS] med_sch=\(med) grd_yr=\(yr)")
        // residency/undergrad intentionally empty — no free authoritative source.
        return CMSProfile(medSchool: med, gradYear: yr, facility: facility, residency: "", undergrad: "")
    }
}
