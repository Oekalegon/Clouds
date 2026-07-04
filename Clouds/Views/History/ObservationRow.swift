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
        }
    }
}

#Preview {
    ObservationRow(observation: CloudObservation())
}
