//
//  IdentifyPhotoView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import SwiftUI
import PhotosUI
import UIKit

/// First screen of the identify flow: lets the user optionally attach a
/// photo (camera or library) before starting the Q&A. The photo is never
/// required to proceed, matching how location capture never blocks saving.
struct IdentifyPhotoView: View {
    @Binding var photoData: Data?
    /// The photo's own capture date when it came from the library, so the
    /// observation can be dated by when the cloud was actually seen rather
    /// than when it was added. `nil` for camera captures, which are already
    /// happening in the moment.
    @Binding var photoDate: Date?
    /// The photo's own EXIF GPS location when it came from the library, so
    /// the observation can be placed where the photo was actually taken
    /// rather than wherever the user happens to be now. `nil` for camera
    /// captures, which use the device's current location. Set immediately
    /// with the bare coordinate; the reverse-geocoded place name fills in
    /// once the lookup finishes.
    @Binding var photoLocation: CapturedLocation?
    /// Where the current photo came from — the caller shapes the rest of
    /// the flow on this (a library photo skips the sky-conditions steps).
    @Binding var photoOrigin: PhotoOrigin
    /// Additional observations under an already-recorded sky condition
    /// must show the current sky, so the library option is hidden for them.
    var allowsLibrary = true
    let onStart: () -> Void

    private enum PhotoSource: Equatable {
        case camera
        case library
    }

    @State private var isShowingSourceDialog = false
    @State private var activePhotoSource: PhotoSource?
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var libraryLoadErrorMessage: String?
    @State private var isShowingCameraPermissionDeniedAlert = false

    /// Bridges `activePhotoSource` to the `Bool` bindings `fullScreenCover`/
    /// `photosPicker` require, so at most one of camera/library can ever be
    /// presented at a time — enforced by `activePhotoSource` being a single
    /// optional value, not two independently-settable booleans.
    private var isShowingCamera: Binding<Bool> {
        Binding(
            get: { activePhotoSource == .camera },
            set: { if !$0 { activePhotoSource = nil } }
        )
    }

    private var isShowingLibraryPicker: Binding<Bool> {
        Binding(
            get: { activePhotoSource == .library },
            set: { if !$0 { activePhotoSource = nil } }
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            photoWell

            Button(photoData == nil ? "Add Photo" : "Retake Photo") {
                isShowingSourceDialog = true
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Start Identification", action: onStart)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .confirmationDialog("Add Photo", isPresented: $isShowingSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    Task {
                        if await CameraAuthorization.requestAccess() {
                            activePhotoSource = .camera
                        } else {
                            isShowingCameraPermissionDeniedAlert = true
                        }
                    }
                }
            }
            if allowsLibrary {
                Button("Choose from Library") { activePhotoSource = .library }
            }
            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    photoDate = nil
                    photoLocation = nil
                    photoOrigin = .none
                    selectedLibraryItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: isShowingCamera) {
            CameraCaptureView { data in
                if let data {
                    photoData = data
                    photoDate = nil
                    photoLocation = nil
                    photoOrigin = .camera
                    selectedLibraryItem = nil
                }
                activePhotoSource = nil
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: isShowingLibraryPicker, selection: $selectedLibraryItem, matching: .images)
        .onChange(of: selectedLibraryItem) { _, newItem in
            Task {
                do {
                    if let newItem, let data = try await newItem.loadTransferable(type: Data.self) {
                        photoData = data
                        photoDate = PhotoCaptureDateExtractor.captureDate(from: data)
                        photoOrigin = .library
                        await updatePhotoLocation(for: data)
                    }
                } catch {
                    libraryLoadErrorMessage = "Couldn't load that photo. Please try again."
                }
            }
        }
        .alert(
            "Photo Unavailable",
            isPresented: Binding(
                get: { libraryLoadErrorMessage != nil },
                set: { if !$0 { libraryLoadErrorMessage = nil } }
            )
        ) {
            Button("OK") { libraryLoadErrorMessage = nil }
        } message: {
            Text(libraryLoadErrorMessage ?? "")
        }
        .alert("Camera Access Needed", isPresented: $isShowingCameraPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable camera access in Settings to take a photo of your cloud observation.")
        }
    }

    /// Publishes the library photo's EXIF GPS coordinate right away, then
    /// fills in the reverse-geocoded place name once the lookup finishes —
    /// so a user who races through the flow still gets the coordinate saved.
    /// The geocoding result is dropped if the photo changed underneath it.
    private func updatePhotoLocation(for data: Data) async {
        guard let coordinate = PhotoGPSCoordinateExtractor.coordinate(from: data) else {
            photoLocation = nil
            return
        }
        photoLocation = CapturedLocation(coordinate: coordinate, placeName: nil)
        let placeName = await ReverseGeocoder.placeName(for: coordinate)
        if photoData == data {
            photoLocation = CapturedLocation(coordinate: coordinate, placeName: placeName)
        }
    }

    @ViewBuilder
    private var photoWell: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.secondary.opacity(0.15))
            .frame(width: 240, height: 240)
            .overlay {
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    IdentifyPhotoView(
        photoData: .constant(nil),
        photoDate: .constant(nil),
        photoLocation: .constant(nil),
        photoOrigin: .constant(.none),
        onStart: {}
    )
}
