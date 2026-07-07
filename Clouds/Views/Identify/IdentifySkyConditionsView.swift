//
//  IdentifySkyConditionsView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import SwiftUI

/// Second screen of the identify flow: records how much of the sky is
/// covered before the Q&A about the individual cloud starts. The value
/// applies to the whole sky, so it is asked once even when several clouds
/// are identified in the same session.
struct IdentifySkyConditionsView: View {
    @Binding var cloudCoverEighths: Int
    @Binding var isSkyObscured: Bool
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

            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    @Previewable @State var eighths = 3
    @Previewable @State var obscured = false
    IdentifySkyConditionsView(
        cloudCoverEighths: $eighths,
        isSkyObscured: $obscured,
        onContinue: {}
    )
}
