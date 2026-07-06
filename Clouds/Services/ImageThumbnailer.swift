//
//  ImageThumbnailer.swift
//  Clouds
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import ImageIO
import UniformTypeIdentifiers

/// Generates small downsampled JPEG thumbnails from full-resolution photo
/// data. Uses ImageIO's thumbnail generation rather than decoding the full
/// image and resizing it, so a multi-megapixel camera capture never gets
/// fully decoded into memory just to produce a few-hundred-pixel preview.
enum ImageThumbnailer {
    static func downsampledJPEGData(from data: Data, maxPixelSize: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }
}
