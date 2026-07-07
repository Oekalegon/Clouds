//
//  WeatherSummaryView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import SwiftUI

/// Compact two-line summary of a weather snapshot, shown on the
/// sky-conditions step and the sky-condition summary once the WeatherKit
/// fetch resolves.
struct WeatherSummaryView: View {
    let weather: SkyConditions.WeatherSnapshot

    var body: some View {
        VStack(spacing: 4) {
            Label(
                "\(Int(weather.temperatureCelsius.rounded()))°C, \(weather.condition)",
                systemImage: weather.symbolName
            )
            .font(.subheadline)
            Text("\(Int(weather.pressureHectopascals.rounded())) hPa · \(Int((weather.humidity * 100).rounded()))% humidity")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WeatherSummaryView(weather: SkyConditions.WeatherSnapshot(
        date: .now,
        temperatureCelsius: 21.3,
        apparentTemperatureCelsius: 20.8,
        humidity: 0.65,
        dewPointCelsius: 14.5,
        pressureHectopascals: 1013.2,
        pressureTrend: "steady",
        cloudCover: 0.6,
        visibilityMeters: 20_000,
        uvIndex: 4,
        isDaylight: true,
        condition: "Partly Cloudy",
        symbolName: "cloud.sun",
        windSpeedKph: 12,
        windGustKph: nil,
        windDirectionDegrees: 270,
        windCompassDirection: "west"
    ))
}
