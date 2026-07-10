//
//  DebugPosteriorView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 08/07/2026.
//

import SwiftUI

/// TEMPORARY (CLD-9 debugging): shows the current genus posterior, most
/// likely first, so the redesigned network's behaviour can be watched live
/// while answering questions. Remove once the network's calibration is
/// trusted enough not to need this.
struct DebugPosteriorView: View {
    let posterior: [StateID: Double]
    var supplementaryFeatures: [NodeID] = []
    var accessoryClouds: [NodeID] = []

    private static let maxGeneraShown = 5

    var body: some View {
        let ranked = posterior
            .sorted { $0.value > $1.value }
            .prefix(Self.maxGeneraShown)

        VStack(alignment: .leading, spacing: 2) {
            Text("DEBUG POSTERIOR")
                .font(.caption2.bold())
            ForEach(Array(ranked), id: \.key) { state, probability in
                Text("\(CloudGenus(rawValue: state)?.displayName ?? state): \(probability, format: .percent.precision(.fractionLength(1)))")
                    .font(.caption2.monospacedDigit())
            }
            if !supplementaryFeatures.isEmpty {
                Text("Features: \(supplementaryFeatures.joined(separator: ", "))")
                    .font(.caption2)
            }
            if !accessoryClouds.isEmpty {
                Text("Accessory: \(accessoryClouds.joined(separator: ", "))")
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(.yellow.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.black)
    }
}

#Preview {
    DebugPosteriorView(
        posterior: ["Cb": 0.62, "Cu": 0.21, "Sc": 0.09, "Ac": 0.05, "St": 0.02, "Ci": 0.01],
        supplementaryFeatures: ["Incus", "Mamma"],
        accessoryClouds: ["Pannus"]
    )
}
