//
//  IdentifyView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import SwiftUI
import SwiftData

struct IdentifyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var session = IdentificationSession()
    @State private var locationProvider = LocationProvider()
    @State private var capturedLocation: LocationProvider.CapturedLocation?

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button("Back", systemImage: "chevron.backward") {
                            Task { await session.goBack() }
                        }
                        .disabled(!session.canGoBack)
                    }
                    ToolbarItem(placement: .navigation) {
                        Button("Forward", systemImage: "chevron.forward") {
                            Task { await session.goForward() }
                        }
                        .disabled(!session.canGoForward)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                .task {
                    await session.start()
                }
                .task {
                    capturedLocation = await locationProvider.captureCurrentLocation()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if session.isComputingNextQuestion {
            ProgressView()
        } else if session.isFinished {
            IdentifyResultView(
                genus: session.mostLikelyGenus.flatMap(CloudGenus.init),
                confidence: session.posterior.values.max() ?? 0,
                onSave: save
            )
        } else if let question = session.currentQuestion() {
            IdentifyQuestionView(
                question: question,
                selectedAnswer: session.currentAnswer,
                onSelect: { state in
                    Task { await session.selectAnswer(state) }
                }
            )
        } else {
            ProgressView()
        }
    }

    private func save() {
        guard let genus = session.mostLikelyGenus.flatMap(CloudGenus.init) else { return }
        let observation = CloudObservation(
            latitude: capturedLocation?.coordinate.latitude,
            longitude: capturedLocation?.coordinate.longitude,
            placeName: capturedLocation?.placeName,
            genus: genus.displayName
        )
        modelContext.insert(observation)
        dismiss()
    }
}

#Preview {
    IdentifyView()
        .modelContainer(for: CloudObservation.self, inMemory: true)
}
