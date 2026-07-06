//
//  PhotoCaptureDateExtractor.swift
//  Clouds
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import Foundation
import ImageIO

/// Reads the capture date embedded in a photo's EXIF/TIFF metadata, so a
/// photo picked from the library can be dated by when it was actually taken
/// rather than when it was added to an observation.
enum PhotoCaptureDateExtractor {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    static func captureDate(from data: Data) -> Date? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
           let date = dateFormatter.date(from: raw) {
            return date
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = dateFormatter.date(from: raw) {
            return date
        }

        return nil
    }
}
