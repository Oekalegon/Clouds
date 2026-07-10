//
//  ObservationRow.swift
//  Clouds
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import SwiftUI
import UIKit

struct ObservationRow: View {
    let observation: CloudObservation

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

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
                if let specialFeature = observation.specialFeature {
                    Text(specialFeature)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailData = observation.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    ObservationRow(observation: CloudObservation())
}

#Preview("With place name") {
    ObservationRow(observation: CloudObservation(latitude: 52.3676, longitude: 4.9041, placeName: "Amsterdam, Netherlands", genus: "Cumulonimbus"))
}
