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
    let onSave: () -> Void
    /// Saves this observation and starts identifying another cloud present
    /// in the same sky, sharing the already-recorded sky conditions.
    let onSaveAndAddAnother: () -> Void

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

            Spacer()

            Button("Save Observation") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .disabled(genus == nil)

            Button("Save & Identify Another Cloud") {
                onSaveAndAddAnother()
            }
            .buttonStyle(.bordered)
            .disabled(genus == nil)
        }
        .padding()
    }
}

#Preview {
    IdentifyResultView(genus: .cumulonimbus, confidence: 0.92, onSave: {}, onSaveAndAddAnother: {})
}
