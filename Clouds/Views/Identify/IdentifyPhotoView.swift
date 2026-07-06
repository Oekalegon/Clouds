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
    let onStart: () -> Void

    @State private var isShowingSourceDialog = false
    @State private var isShowingCamera = false
    @State private var isShowingLibraryPicker = false
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var libraryLoadErrorMessage: String?
    @State private var isShowingCameraPermissionDeniedAlert = false

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
                            isShowingCamera = true
                        } else {
                            isShowingCameraPermissionDeniedAlert = true
                        }
                    }
                }
            }
            Button("Choose from Library") { isShowingLibraryPicker = true }
            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    selectedLibraryItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { data in
                if let data {
                    photoData = data
                    selectedLibraryItem = nil
                }
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isShowingLibraryPicker, selection: $selectedLibraryItem, matching: .images)
        .onChange(of: selectedLibraryItem) { _, newItem in
            Task {
                do {
                    if let newItem, let data = try await newItem.loadTransferable(type: Data.self) {
                        photoData = data
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
    IdentifyPhotoView(photoData: .constant(nil), onStart: {})
}
