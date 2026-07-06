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

    private func cgImage() -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.cgImage!
    }

    private func imageData(uti: CFString, properties: [CFString: Any] = [:]) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, uti, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage(), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func jpegData(properties: [CFString: Any] = [:]) -> Data {
        imageData(uti: UTType.jpeg.identifier as CFString, properties: properties)
    }

    private func components(
        of date: Date,
        in timeZone: TimeZone
    ) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    @Test func captureDateParsesExifDateTimeOriginal() throws {
        let data = jpegData(properties: [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:03:15 14:30:00"
            ]
        ])

        let date = try #require(PhotoCaptureDateExtractor.captureDate(from: data))

        let parsed = components(of: date, in: .current)
        #expect(parsed.year == 2026)
        #expect(parsed.month == 3)
        #expect(parsed.day == 15)
        #expect(parsed.hour == 14)
        #expect(parsed.minute == 30)
        #expect(parsed.second == 0)
    }

    @Test func captureDateAppliesExifOffsetTimeOriginalRegardlessOfDeviceTimeZone() throws {
        let data = jpegData(properties: [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:03:15 23:30:00",
                kCGImagePropertyExifOffsetTimeOriginal: "+09:00"
            ]
        ])

        let date = try #require(PhotoCaptureDateExtractor.captureDate(from: data))

        let tokyo = try #require(TimeZone(secondsFromGMT: 9 * 3600))
        let parsed = components(of: date, in: tokyo)
        #expect(parsed.year == 2026)
        #expect(parsed.month == 3)
        #expect(parsed.day == 15)
        #expect(parsed.hour == 23)
        #expect(parsed.minute == 30)
        #expect(parsed.second == 0)
    }

    @Test func captureDateFallsBackToTIFFDateTimeWhenNoExifDateTimeOriginalPresent() throws {
        // A JPEG destination silently drops custom TIFF-dictionary tags when
        // re-encoding, so this exercises the fallback branch against actual
        // TIFF container data instead — `captureDate` reads whatever
        // properties ImageIO exposes regardless of the underlying format.
        let data = imageData(uti: UTType.tiff.identifier as CFString, properties: [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFDateTime: "2025:11:02 08:15:30"
            ]
        ])

        let date = try #require(PhotoCaptureDateExtractor.captureDate(from: data))

        let parsed = components(of: date, in: .current)
        #expect(parsed.year == 2025)
        #expect(parsed.month == 11)
        #expect(parsed.day == 2)
        #expect(parsed.hour == 8)
        #expect(parsed.minute == 15)
        #expect(parsed.second == 30)
    }

    @Test func captureDateReturnsNilForMalformedExifDateString() {
        let data = jpegData(properties: [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "not-a-date"
            ]
        ])

        #expect(PhotoCaptureDateExtractor.captureDate(from: data) == nil)
    }

    @Test func captureDateReturnsNilWhenNoDateMetadataPresent() {
        let data = jpegData()

        #expect(PhotoCaptureDateExtractor.captureDate(from: data) == nil)
    }

    @Test func captureDateReturnsNilForInvalidData() {
        let garbage = Data([0x00, 0x01, 0x02])

        #expect(PhotoCaptureDateExtractor.captureDate(from: garbage) == nil)
    }
}
