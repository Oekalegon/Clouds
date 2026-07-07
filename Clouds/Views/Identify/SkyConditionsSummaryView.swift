//
//  SkyConditionsSummaryView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import SwiftUI

/// Last screen of an in-the-moment identify session: the sky condition
/// just recorded, with its weather shown above the list of observations
/// saved under it so far. From here the user can keep adding observations
/// (another photo + identification of a different cloud in the same sky)
/// or finish.
struct SkyConditionsSummaryView: View {
    let skyConditions: SkyConditions
    let onAddObservation: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Current Sky")
                    .font(.headline)
                if let coverLine = skyConditions.coverLine {
                    Text(coverLine)
                        .font(.title2.bold())
                }
                if let weather = skyConditions.weather {
                    WeatherSummaryView(weather: weather)
                }
            }
            .padding(.top)

            List {
                Section("Observations") {
                    ForEach(skyConditions.observationsByDate) { observation in
                        ObservationRow(observation: observation)
                    }
                }
            }
            .accessibilityIdentifier("SummaryObservationsList")

            VStack(spacing: 12) {
                Button("Add Another Observation", action: onAddObservation)
                    .buttonStyle(.borderedProminent)
                Button("Done", action: onDone)
                    .buttonStyle(.bordered)
            }
            .padding(.bottom)
        }
    }
}

#Preview {
    SkyConditionsSummaryView(
        skyConditions: SkyConditions(cloudCoverEighths: 5),
        onAddObservation: {},
        onDone: {}
    )
}
