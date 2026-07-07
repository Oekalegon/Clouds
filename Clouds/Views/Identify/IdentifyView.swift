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
        case skyConditions
        case photo
        case questions
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var session = IdentificationSession()
    @State private var locationProvider = LocationProvider()
    @State private var capturedLocation: LocationProvider.CapturedLocation?
    @State private var weatherSnapshot: SkyConditions.WeatherSnapshot?
    @State private var photoData: Data?
    @State private var photoDate: Date?
    @State private var step: Step = .skyConditions
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
                    // The flow opens on the sky-conditions step, so this is
                    // always an in-the-moment observation: fetch location and
                    // then current weather straight away, so the conditions
                    // can appear on the sky screen while the user dials in
                    // the cover.
                    capturedLocation = await locationProvider.captureCurrentLocation()
                    if let coordinate = capturedLocation?.coordinate {
                        weatherSnapshot = await WeatherProvider.currentWeather(at: coordinate)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .skyConditions:
            IdentifySkyConditionsView(
                cloudCoverEighths: $cloudCoverEighths,
                isSkyObscured: $isSkyObscured,
                weather: weatherSnapshot,
                onContinue: { step = .photo }
            )
        case .photo:
            IdentifyPhotoView(photoData: $photoData, photoDate: $photoDate, onStart: { step = .questions })
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
        // The fetch races the user through the flow, so a snapshot that
        // arrived after the sky conditions were first saved is filled in
        // here.
        if skyConditions.weather == nil {
            skyConditions.weather = weatherSnapshot
        }
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
            cloudCoverEighths: isSkyObscured ? nil : cloudCoverEighths,
            isSkyObscured: isSkyObscured,
            weather: weatherSnapshot
        )
        modelContext.insert(skyConditions)
        return skyConditions
    }

    /// Loops back to the photo step for another cloud in the same sky:
    /// fresh photo and Q&A, but the sky-conditions step is skipped since
    /// the cover was already recorded for this session.
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
