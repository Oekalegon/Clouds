//
//  PhotoOrigin.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

/// Where the identify flow's photo came from. This drives the flow shape:
/// a camera capture (or no photo at all) is an in-the-moment observation
/// that gets sky conditions (cloud cover, weather), while a library photo
/// may show a sky from any time in the past, so it skips those steps and
/// is saved as a standalone observation.
enum PhotoOrigin {
    case none
    case camera
    case library
}
