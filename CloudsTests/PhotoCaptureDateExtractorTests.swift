//
//  PhotoCaptureDateExtractorTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import Testing
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Clouds

struct PhotoCaptureDateExtractorTests {

    private func jpegData(exifDateTimeOriginal: String?) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let cgImage = image.cgImage!

        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!

        var properties: [CFString: Any] = [:]
        if let exifDateTimeOriginal {
            properties[kCGImagePropertyExifDictionary] = [
                kCGImagePropertyExifDateTimeOriginal: exifDateTimeOriginal
            ]
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func captureDateParsesExifDateTimeOriginal() throws {
        let data = jpegData(exifDateTimeOriginal: "2026:03:15 14:30:00")

        let date = try #require(PhotoCaptureDateExtractor.captureDate(from: data))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
        #expect(components.second == 0)
    }

    @Test func captureDateReturnsNilWhenNoDateMetadataPresent() {
        let data = jpegData(exifDateTimeOriginal: nil)

        #expect(PhotoCaptureDateExtractor.captureDate(from: data) == nil)
    }

    @Test func captureDateReturnsNilForInvalidData() {
        let garbage = Data([0x00, 0x01, 0x02])

        #expect(PhotoCaptureDateExtractor.captureDate(from: garbage) == nil)
    }
}
