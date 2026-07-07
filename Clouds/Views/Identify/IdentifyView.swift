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
    @State private var locationTask: Task<LocationProvider.CapturedLocation?, Never>?
    @State private var capturedLocation: LocationProvider.CapturedLocation?
    @State private var weatherSnapshot: CloudObservation.WeatherSnapshot?
    @State private var photoData: Data?
    @State private var photoDate: Date?
    @State private var isShowingPhotoStep = true

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if !isShowingPhotoStep {
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
                    let task = Task { await locationProvider.captureCurrentLocation() }
                    locationTask = task
                    capturedLocation = await task.value
                }
                .task(id: isShowingPhotoStep) {
                    guard !isShowingPhotoStep, weatherSnapshot == nil else { return }
                    guard WeatherProvider.isEligible(photoDate: photoDate) else { return }
                    guard let coordinate = await locationTask?.value?.coordinate else { return }
                    weatherSnapshot = await WeatherProvider.currentWeather(at: coordinate)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isShowingPhotoStep {
            IdentifyPhotoView(photoData: $photoData, photoDate: $photoDate, onStart: { isShowingPhotoStep = false })
        } else if session.isComputingNextQuestion {
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
        let thumbnailData = photoData.flatMap {
            ImageThumbnailer.downsampledJPEGData(from: $0, maxPixelSize: 300)
        }
        let observation = CloudObservation(
            date: photoDate ?? .now,
            latitude: capturedLocation?.coordinate.latitude,
            longitude: capturedLocation?.coordinate.longitude,
            placeName: capturedLocation?.placeName,
            genus: genus.displayName,
            photoData: photoData,
            thumbnailData: thumbnailData,
            weather: weatherSnapshot
        )
        modelContext.insert(observation)
        dismiss()
    }
}

#Preview {
    IdentifyView()
        .modelContainer(for: CloudObservation.self, inMemory: true)
}
