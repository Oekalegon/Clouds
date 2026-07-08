//
//  LocationProvider.swift
//  Clouds
//
//  Created by Dieudonné Willems on 05/07/2026.
//

import CoreLocation
import os

/// Requests a single current-location fix, plus its reverse-geocoded place
/// name, for populating `CloudObservation`'s location fields. Wraps
/// `CLLocationManager`'s delegate callbacks in `async`/`await` since Core
/// Location has no first-party async API for a one-shot location request.
@MainActor
final class LocationProvider: NSObject {
    nonisolated private static let logger = Logger(subsystem: "no.oekalegon.Clouds", category: "Location")

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Returns the current coordinate and place name, or `nil` if
    /// authorization is denied, restricted, or no fix could be obtained.
    /// Never throws, so a failed or declined location request never blocks
    /// saving an observation. A resolved coordinate with no place name (the
    /// geocoding lookup found nothing, or failed) is still returned, since
    /// the coordinate alone is useful.
    func captureCurrentLocation() async -> CapturedLocation? {
        guard await ensureAuthorization() else { return nil }
        guard let coordinate = await requestCoordinate() else { return nil }
        let placeName = await ReverseGeocoder.placeName(for: coordinate)
        return CapturedLocation(coordinate: coordinate, placeName: placeName)
    }

    private func requestCoordinate() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Resolves once authorization is either already decided or the user
    /// has responded to the system prompt. Calling `requestLocation()`
    /// while still `.notDetermined` fails immediately, so callers must wait
    /// for this before requesting a fix.
    private func ensureAuthorization() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return false
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard let continuation = authorizationContinuation else { return }
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                authorizationContinuation = nil
                continuation.resume(returning: true)
            case .denied, .restricted:
                authorizationContinuation = nil
                continuation.resume(returning: false)
            case .notDetermined:
                break // still waiting on the user's decision
            @unknown default:
                authorizationContinuation = nil
                continuation.resume(returning: false)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            continuation.resume(returning: locations.last?.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            Self.logger.error("Location request failed: \(error.localizedDescription, privacy: .public)")
            continuation.resume(returning: nil)
        }
    }
}
