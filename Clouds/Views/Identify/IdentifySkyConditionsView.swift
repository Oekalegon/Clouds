//
//  IdentifySkyConditionsView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import SwiftUI

/// First screen of the identify flow: records how much of the sky is
/// covered, and shows the fetched weather once it arrives. Both apply to
/// the whole sky, so they are captured once even when several clouds are
/// identified in the same session.
struct IdentifySkyConditionsView: View {
    @Binding var cloudCoverEighths: Int
    @Binding var isSkyObscured: Bool
    /// Current conditions from WeatherKit; `nil` while the fetch is still
    /// running (or when it failed — the screen never blocks on weather).
    let weather: SkyConditions.WeatherSnapshot?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How much of the sky is covered?")
                .font(.headline)
                .multilineTextAlignment(.center)

            ZStack {
                CloudCoverDial(eighths: $cloudCoverEighths)
                    .opacity(isSkyObscured ? 0.25 : 1)
                    .disabled(isSkyObscured)

                if isSkyObscured {
                    VStack(spacing: 4) {
                        Image(systemName: "cloud.fog.fill")
                            .font(.system(size: 40))
                        Text("Sky obscured")
                            .font(.headline)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Toggle("Sky Obscured", systemImage: "cloud.fog", isOn: $isSkyObscured)
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .help("The sky can't be judged because of fog, smoke or haze.")

            Spacer()

            weatherSummary

            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .animation(.default, value: weather == nil)
    }

    @ViewBuilder
    private var weatherSummary: some View {
        if let weather {
            WeatherSummaryView(weather: weather)
                .transition(.opacity)
        }
    }
}

#Preview {
    @Previewable @State var eighths = 3
    @Previewable @State var obscured = false
    IdentifySkyConditionsView(
        cloudCoverEighths: $eighths,
        isSkyObscured: $obscured,
        weather: nil,
        onContinue: {}
    )
}

#Preview("With weather") {
    @Previewable @State var eighths = 5
    @Previewable @State var obscured = false
    IdentifySkyConditionsView(
        cloudCoverEighths: $eighths,
        isSkyObscured: $obscured,
        weather: SkyConditions.WeatherSnapshot(
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
        ),
        onContinue: {}
    )
}
