//
//  IdentifyView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import SwiftUI
import SwiftData

struct IdentifyView: View {
    private enum Step {
        case photo
        case skyConditions
        case questions
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var session = IdentificationSession()
    @State private var locationProvider = LocationProvider()
    @State private var locationTask: Task<LocationProvider.CapturedLocation?, Never>?
    @State private var capturedLocation: LocationProvider.CapturedLocation?
    @State private var weatherSnapshot: SkyConditions.WeatherSnapshot?
    @State private var photoData: Data?
    @State private var photoDate: Date?
    @State private var step: Step = .photo
    @State private var cloudCoverEighths = 0
    @State private var isSkyObscured = false
    /// The sky conditions saved with the first observation of this session,
    /// reused when the user identifies further clouds present in the same
    /// sky.
    @State private var savedSkyConditions: SkyConditions?

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if step == .questions {
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
                .task(id: step) {
                    guard step != .photo, weatherSnapshot == nil else { return }
                    guard WeatherProvider.isEligible(photoDate: photoDate) else { return }
                    guard let coordinate = await locationTask?.value?.coordinate else { return }
                    weatherSnapshot = await WeatherProvider.currentWeather(at: coordinate)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .photo:
            IdentifyPhotoView(photoData: $photoData, photoDate: $photoDate, onStart: {
                // The cover was already recorded when this session's first
                // observation was saved; go straight to the questions for
                // the next cloud.
                step = savedSkyConditions == nil ? .skyConditions : .questions
            })
        case .skyConditions:
            IdentifySkyConditionsView(
                cloudCoverEighths: $cloudCoverEighths,
                isSkyObscured: $isSkyObscured,
                onContinue: { step = .questions }
            )
        case .questions:
            questionContent
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        if session.isComputingNextQuestion {
            ProgressView()
        } else if session.isFinished {
            IdentifyResultView(
                genus: session.mostLikelyGenus.flatMap(CloudGenus.init),
                confidence: session.posterior.values.max() ?? 0,
                onSave: {
                    save()
                    dismiss()
                },
                onSaveAndAddAnother: {
                    save()
                    startNextIdentification()
                }
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
        let skyConditions = savedSkyConditions ?? makeSkyConditions()
        savedSkyConditions = skyConditions
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
            skyConditions: skyConditions
        )
        modelContext.insert(observation)
    }

    private func makeSkyConditions() -> SkyConditions {
        let skyConditions = SkyConditions(
            date: photoDate ?? .now,
            cloudCoverEighths: isSkyObscured ? nil : cloudCoverEighths,
            isSkyObscured: isSkyObscured,
            weather: weatherSnapshot
        )
        modelContext.insert(skyConditions)
        return skyConditions
    }

    /// Loops back to the photo step for another cloud in the same sky:
    /// fresh photo and Q&A, but the already-saved sky conditions (and the
    /// weather fetched for them) are kept.
    private func startNextIdentification() {
        photoData = nil
        photoDate = nil
        step = .photo
        let nextSession = IdentificationSession()
        session = nextSession
        Task { await nextSession.start() }
    }
}

#Preview {
    IdentifyView()
        .modelContainer(for: CloudObservation.self, inMemory: true)
}
