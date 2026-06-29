// aegis_mapkit_search_260629.swift
// Added 260629: Native MapKit nearby-provider search. NO Google Maps, NO API key.
// Geocodes the authoritative NPI address, then MKLocalSearch for wellness providers
// within ~5km. Returns the top matches as graph "provider" nodes ("in the area").
import Foundation
import MapKit
import CoreLocation

enum MapSearch {
    /// Geocode an address string, then local-search nearby mental-health / wellness providers.
    static func nearbyWellnessProviders(address: String, limit: Int = 5) async throws -> [WellnessProvider] {
        AegisLog.entry("MapSearch.nearbyWellnessProviders", "addrLen=\(address.count)")
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AegisError.geocodeFailed("empty address")
        }

        let placemarks = try await CLGeocoder().geocodeAddressString(address)
        guard let coord = placemarks.first?.location?.coordinate else {
            throw AegisError.geocodeFailed("no coordinate for '\(address)'")
        }
        let origin = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "mental health and wellness providers"
        request.region = MKCoordinateRegion(center: coord,
                                            latitudinalMeters: 5000,
                                            longitudinalMeters: 5000)

        let response = try await MKLocalSearch(request: request).start()
        let providers: [WellnessProvider] = response.mapItems.prefix(limit).map { item in
            let loc = item.placemark.location
            let dist = loc.map { origin.distance(from: $0) }
            return WellnessProvider(
                name: item.name ?? "Unknown",
                address: item.placemark.title ?? "",
                distanceMeters: dist
            )
        }
        AegisLog.info("[MAP] \(providers.count) nearby wellness providers")
        return providers
    }
}
