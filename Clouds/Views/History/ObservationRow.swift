//
//  ObservationRow.swift
//  Clouds
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import SwiftUI

struct ObservationRow: View {
    let observation: CloudObservation

    var body: some View {
        VStack(alignment: .leading) {
            Text(observation.genus ?? "Unidentified Cloud")
                .font(.headline)
            Text(observation.date, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let placeName = observation.placeName {
                Text(placeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ObservationRow(observation: CloudObservation())
}

#Preview("With place name") {
    ObservationRow(observation: CloudObservation(latitude: 52.3676, longitude: 4.9041, placeName: "Amsterdam, Netherlands", genus: "Cumulonimbus"))
}
