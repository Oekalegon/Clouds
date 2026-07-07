//
//  WeatherProvider.swift
//  Clouds
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import CoreLocation
import WeatherKit
import os

/// Fetches current conditions for an observation's coordinate. WeatherKit
/// only exposes current/forecast data, not a historical archive, so callers
/// should only invoke this for "in the moment" observations — see
/// `isEligible(photoDate:)`.
enum WeatherProvider {
    nonisolated private static let logger = Logger(subsystem: "no.oekalegon.Clouds", category: "Weather")

    /// How stale a library photo's EXIF capture date can be before current
    /// conditions are no longer a reasonable stand-in for what it was like
    /// when the cloud was actually photographed.
    private static let maxPhotoAge: TimeInterval = 15 * 60

    /// Returns `nil` on any failure, since a failed weather lookup should
    /// never block saving an observation — mirrors `LocationProvider`.
    static func currentWeather(at coordinate: CLLocationCoordinate2D) async -> CloudObservation.WeatherSnapshot? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            return CloudObservation.WeatherSnapshot(current)
        } catch {
            logger.error("Weather lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Whether weather is worth fetching for a given photo's capture date.
    /// `nil` covers both a camera capture (happening live) and no photo at
    /// all; either way there's no EXIF date to check.
    static func isEligible(photoDate: Date?, now: Date = .now) -> Bool {
        guard let photoDate else { return true }
        return now.timeIntervalSince(photoDate) <= maxPhotoAge
    }
}

private extension CloudObservation.WeatherSnapshot {
    init(_ current: CurrentWeather) {
        self.init(
            date: current.date,
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            apparentTemperatureCelsius: current.apparentTemperature.converted(to: .celsius).value,
            humidity: current.humidity,
            dewPointCelsius: current.dewPoint.converted(to: .celsius).value,
            pressureHectopascals: current.pressure.converted(to: .hectopascals).value,
            pressureTrend: String(describing: current.pressureTrend),
            cloudCover: current.cloudCover,
            visibilityMeters: current.visibility.converted(to: .meters).value,
            uvIndex: current.uvIndex.value,
            isDaylight: current.isDaylight,
            condition: current.condition.description,
            symbolName: current.symbolName,
            windSpeedKph: current.wind.speed.converted(to: .kilometersPerHour).value,
            windGustKph: current.wind.gust.map { $0.converted(to: .kilometersPerHour).value },
            windDirectionDegrees: current.wind.direction.converted(to: .degrees).value,
            windCompassDirection: String(describing: current.wind.compassDirection)
        )
    }
}
