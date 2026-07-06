//
//  CameraAuthorization.swift
//  Clouds
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import AVFoundation

/// Resolves camera authorization before presenting `CameraCaptureView`,
/// since `UIImagePickerController` itself doesn't reliably prompt or
/// recover when access was previously denied.
enum CameraAuthorization {
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
