//
//  CapturedLocation.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import CoreLocation

/// A resolved coordinate plus its reverse-geocoded place name, ready to be
/// stored on a `CloudObservation`. Produced by `LocationProvider` for
/// in-the-moment observations and from EXIF GPS metadata for library photos.
struct CapturedLocation {
    let coordinate: CLLocationCoordinate2D
    let placeName: String?
}
