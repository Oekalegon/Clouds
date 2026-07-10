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
        case summary
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var session = IdentificationSession()
    @State private var locationProvider = LocationProvider()
    @State private var locationTask: Task<CapturedLocation?, Never>?
    @State private var capturedLocation: CapturedLocation?
    @State private var weatherSnapshot: SkyConditions.WeatherSnapshot?
    @State private var photoData: Data?
    @State private var photoDate: Date?
    @State private var photoLocation: CapturedLocation?
    @State private var photoOrigin: PhotoOrigin = .none
    @State private var step: Step = .photo
    @State private var cloudCoverEighths = 0
    @State private var isSkyObscured = false
    /// The sky conditions saved with the first observation of this session,
    /// reused when the user identifies further clouds present in the same
    /// sky. Stays `nil` for library-photo sessions, whose observations are
    /// saved standalone.
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
                .task(id: shouldFetchWeather) {
                    // Weather belongs to sky conditions, so it's only worth
                    // fetching for an in-the-moment session — a library
                    // photo's sky may be long gone. Keyed on the one
                    // transition that matters (leaving the photo step, once
                    // the origin is known) rather than on every step change,
                    // which would cancel and restart an in-flight fetch.
                    guard shouldFetchWeather, weatherSnapshot == nil else { return }
                    guard let coordinate = await locationTask?.value?.coordinate else { return }
                    weatherSnapshot = await WeatherProvider.currentWeather(at: coordinate)
                    // The fetch races the user through the flow: fill in
                    // sky conditions that were already saved without it.
                    if let savedSkyConditions, savedSkyConditions.weather == nil {
                        savedSkyConditions.weather = weatherSnapshot
                    }
                }
        }
    }

    private var shouldFetchWeather: Bool {
        step != .photo && photoOrigin != .library
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .photo:
            IdentifyPhotoView(
                photoData: $photoData,
                photoDate: $photoDate,
                photoLocation: $photoLocation,
                photoOrigin: $photoOrigin,
                allowsLibrary: savedSkyConditions == nil,
                onStart: {
                    // Library photos skip the sky-conditions step entirely;
                    // in-session additions skip it because the cover was
                    // already recorded.
                    if photoOrigin == .library || savedSkyConditions != nil {
                        step = .questions
                    } else {
                        step = .skyConditions
                    }
                }
            )
        case .skyConditions:
            IdentifySkyConditionsView(
                cloudCoverEighths: $cloudCoverEighths,
                isSkyObscured: $isSkyObscured,
                weather: weatherSnapshot,
                onContinue: { step = .questions }
            )
        case .questions:
            questionContent
        case .summary:
            if let savedSkyConditions {
                SkyConditionsSummaryView(
                    skyConditions: savedSkyConditions,
                    onAddObservation: startNextIdentification,
                    onDone: { dismiss() }
                )
            }
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
                posterior: session.posterior,
                supplementaryFeatures: session.detectedSupplementaryFeatures,
                accessoryClouds: session.detectedAccessoryClouds,
                onSave: {
                    guard save() else { return }
                    // A standalone library observation has no sky-condition
                    // session to return to.
                    if photoOrigin == .library {
                        dismiss()
                    } else {
                        step = .summary
                    }
                }
            )
        } else if let question = session.currentQuestion() {
            IdentifyQuestionView(
                question: question,
                selectedAnswer: session.currentAnswer,
                posterior: session.posterior,
                supplementaryFeatures: session.detectedSupplementaryFeatures,
                accessoryClouds: session.detectedAccessoryClouds,
                onSelect: { state in
                    Task { await session.selectAnswer(state) }
                }
            )
        } else {
            ProgressView()
        }
    }

    /// Returns whether an observation was actually saved, so the caller
    /// never navigates onwards (to the summary, or dismissal) after the
    /// no-genus guard bailed out.
    private func save() -> Bool {
        guard let genus = session.mostLikelyGenus.flatMap(CloudGenus.init) else { return false }
        let thumbnailData = photoData.flatMap {
            ImageThumbnailer.downsampledJPEGData(from: $0, maxPixelSize: 300)
        }
        // A library photo may have been taken far from where the user is
        // now, so today's location would be confidently wrong — its own
        // EXIF GPS (or nothing) is the honest source.
        let location = photoOrigin == .library ? photoLocation : capturedLocation
        let observation = CloudObservation(
            date: photoDate ?? .now,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            placeName: location?.placeName,
            genus: genus.displayName,
            specialFeature: CloudObservation.specialFeatureText(
                supplementaryFeatures: session.detectedSupplementaryFeatures,
                accessoryClouds: session.detectedAccessoryClouds
            ),
            photoData: photoData,
            thumbnailData: thumbnailData
        )
        // A library photo may show a sky from any time in the past, so its
        // observation stays standalone; everything else joins this
        // session's sky conditions.
        if photoOrigin != .library {
            let skyConditions = savedSkyConditions ?? makeSkyConditions()
            savedSkyConditions = skyConditions
            if skyConditions.weather == nil {
                skyConditions.weather = weatherSnapshot
            }
            observation.skyConditions = skyConditions
        }
        modelContext.insert(observation)
        return true
    }

    private func makeSkyConditions() -> SkyConditions {
        let skyConditions = SkyConditions(
            cloudCoverEighths: cloudCoverEighths,
            isSkyObscured: isSkyObscured,
            weather: weatherSnapshot
        )
        modelContext.insert(skyConditions)
        return skyConditions
    }

    /// Loops back to the photo step for another observation in the same
    /// sky: fresh photo and Q&A, but the sky-conditions step is skipped
    /// since the cover was already recorded for this session.
    private func startNextIdentification() {
        photoData = nil
        photoDate = nil
        photoLocation = nil
        photoOrigin = .none
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
