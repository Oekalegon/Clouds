//
//  IdentifyResultView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import SwiftUI

struct IdentifyResultView: View {
    let genus: CloudGenus?
    let confidence: Double
    let posterior: [StateID: Double]
    /// WMO Supplementary Features observed this session (Incus, Mamma, ...).
    let supplementaryFeatures: [NodeID]
    /// WMO Accessory Clouds observed this session (Pileus, Velum, ...).
    let accessoryClouds: [NodeID]
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cloud.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(genus?.displayName ?? "Unidentified Cloud")
                .font(.largeTitle.bold())

            Text(confidence, format: .percent.precision(.fractionLength(0)))
                .foregroundStyle(.secondary)

            if !supplementaryFeatures.isEmpty || !accessoryClouds.isEmpty {
                VStack(spacing: 6) {
                    if !supplementaryFeatures.isEmpty {
                        FeatureChipRow(title: "Supplementary features", names: supplementaryFeatures)
                    }
                    if !accessoryClouds.isEmpty {
                        FeatureChipRow(title: "Accessory clouds", names: accessoryClouds)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            Button("Save Observation") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .disabled(genus == nil)
        }
        .padding()
        .overlay(alignment: .topTrailing) {
            DebugPosteriorView(
                posterior: posterior,
                supplementaryFeatures: supplementaryFeatures,
                accessoryClouds: accessoryClouds
            )
            .padding()
        }
    }
}

private struct FeatureChipRow: View {
    let title: String
    let names: [NodeID]

    var body: some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
    }
}

#Preview {
    IdentifyResultView(
        genus: .cumulonimbus,
        confidence: 0.92,
        posterior: ["Cb": 0.92, "Cu": 0.05, "Sc": 0.02, "Ac": 0.01],
        supplementaryFeatures: ["Incus", "Mamma", "Arcus"],
        accessoryClouds: ["Pannus"],
        onSave: {}
    )
}
