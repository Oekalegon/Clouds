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
                if let skyLine {
                    Text(skyLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// One line summarising the sky the cloud was seen in, e.g.
    /// "3/8 cover · 21°C, Partly cloudy" — whichever parts were recorded.
    private var skyLine: String? {
        guard let skyConditions = observation.skyConditions else { return nil }
        var parts: [String] = []
        if let cover = skyConditions.cloudCoverDescription {
            parts.append(skyConditions.isSkyObscured ? cover : String(localized: "\(cover) cover"))
        }
        if let weather = skyConditions.weather {
            parts.append("\(Int(weather.temperatureCelsius.rounded()))°C, \(weather.condition)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
