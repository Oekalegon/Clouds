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
/// only exposes current/forecast data, not a historical archive, which is
/// fine here: the identify flow opens on the sky-conditions step, so the
/// fetch always describes the sky the user is looking at.
enum WeatherProvider {
    nonisolated private static let logger = Logger(subsystem: "no.oekalegon.Clouds", category: "Weather")

    /// Returns `nil` on any failure, since a failed weather lookup should
    /// never block saving an observation — mirrors `LocationProvider`.
    static func currentWeather(at coordinate: CLLocationCoordinate2D) async -> SkyConditions.WeatherSnapshot? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            return SkyConditions.WeatherSnapshot(current)
        } catch {
            logger.error("Weather lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

private extension SkyConditions.WeatherSnapshot {
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
