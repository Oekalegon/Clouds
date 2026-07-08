//
//  ReverseGeocoder.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import CoreLocation
import MapKit
import os

/// Resolves a coordinate to a human-readable place name for display on an
/// observation. Shared by the current-location capture and the library-photo
/// EXIF GPS flow so both produce place names in the same format.
enum ReverseGeocoder {
    private static let logger = Logger(subsystem: "no.oekalegon.Clouds", category: "Location")

    /// Returns `nil` when the lookup found nothing or failed; callers keep
    /// the bare coordinate in that case, which is still useful on its own.
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            let mapItem = try await request.mapItems.first
            return mapItem?.addressRepresentations?.cityWithContext(.full)
        } catch {
            logger.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
