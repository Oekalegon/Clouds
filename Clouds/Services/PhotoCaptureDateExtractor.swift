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
    static func captureDate(from data: Data) -> Date? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        // EXIF's DateTimeOriginal is a naive local time with no timezone of
        // its own; OffsetTimeOriginal (EXIF 2.31+) supplies the UTC offset
        // that was actually in effect at capture, so a photo taken abroad is
        // dated by the moment it was taken rather than shifted by whatever
        // zone this device happens to be in when the photo is later picked.
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let zone = (exif[kCGImagePropertyExifOffsetTimeOriginal] as? String)
                .flatMap(timeZone(fromExifOffset:)) ?? .current
            if let date = date(from: raw, timeZone: zone) {
                return date
            }
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = date(from: raw, timeZone: .current) {
            return date
        }

        return nil
    }

    private static func date(from raw: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.date(from: raw)
    }

    /// Parses an EXIF UTC offset string such as `"+09:00"` or `"-05:00"`.
    private static func timeZone(fromExifOffset offset: String) -> TimeZone? {
        guard offset.count == 6, let sign = offset.first, sign == "+" || sign == "-" else { return nil }
        let components = offset.dropFirst().split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1])
        else { return nil }

        let totalSeconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: totalSeconds)
    }
}
