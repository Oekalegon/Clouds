//
//  PhotoGPSCoordinateExtractor.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import CoreLocation
import Foundation
import ImageIO

/// Reads the GPS coordinate embedded in a photo's EXIF metadata, so a photo
/// picked from the library can be located where it was actually taken rather
/// than wherever the device happens to be when the photo is picked.
enum PhotoGPSCoordinateExtractor {
    static func coordinate(from data: Data) -> CLLocationCoordinate2D? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        else { return nil }
        return coordinate(fromGPSDictionary: gps)
    }

    /// Internal rather than private so the sign handling can be unit-tested
    /// directly: `CGImageDestination` normalises GPS metadata on write, so a
    /// signed value without a hemisphere reference can't be round-tripped
    /// through encoded image data in tests, even though real files written
    /// by other software do carry that shape.
    static func coordinate(fromGPSDictionary gps: [CFString: Any]) -> CLLocationCoordinate2D? {
        guard
            let latitude = signedDegrees(
                value: gps[kCGImagePropertyGPSLatitude],
                reference: gps[kCGImagePropertyGPSLatitudeRef],
                negatingReference: "S"
            ),
            let longitude = signedDegrees(
                value: gps[kCGImagePropertyGPSLongitude],
                reference: gps[kCGImagePropertyGPSLongitudeRef],
                negatingReference: "W"
            )
        else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }

    /// EXIF stores latitude/longitude as an unsigned magnitude plus a
    /// hemisphere reference (`"N"`/`"S"`, `"E"`/`"W"`). Some writers instead
    /// bake the sign into the value and omit the reference, so the value's
    /// own sign is kept when no reference is present.
    private static func signedDegrees(
        value: Any?,
        reference: Any?,
        negatingReference: String
    ) -> Double? {
        guard let degrees = value as? Double else { return nil }
        if let reference = reference as? String, reference == negatingReference {
            return -abs(degrees)
        }
        return degrees
    }
}
