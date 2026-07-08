//
//  PhotoGPSCoordinateExtractorTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Testing
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Clouds

struct PhotoGPSCoordinateExtractorTests {

    private func cgImage() -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.cgImage!
    }

    private func jpegData(gps: [CFString: Any]? = nil) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [:]
        if let gps {
            properties[kCGImagePropertyGPSDictionary] = gps
        }
        CGImageDestinationAddImage(destination, cgImage(), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func coordinateParsesNorthEastHemispheres() throws {
        let data = jpegData(gps: [
            kCGImagePropertyGPSLatitude: 52.3676,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 4.9041,
            kCGImagePropertyGPSLongitudeRef: "E"
        ])

        let coordinate = try #require(PhotoGPSCoordinateExtractor.coordinate(from: data))

        #expect(abs(coordinate.latitude - 52.3676) < 0.0001)
        #expect(abs(coordinate.longitude - 4.9041) < 0.0001)
    }

    // The tests below drive the GPS-dictionary parsing directly:
    // `CGImageDestination` normalises GPS metadata on write, so shapes like
    // a signed value without a hemisphere reference cannot be round-tripped
    // through encoded image data, even though other software writes them.

    @Test func coordinateNegatesSouthWestHemispheres() throws {
        let coordinate = try #require(PhotoGPSCoordinateExtractor.coordinate(fromGPSDictionary: [
            kCGImagePropertyGPSLatitude: 33.8688,
            kCGImagePropertyGPSLatitudeRef: "S",
            kCGImagePropertyGPSLongitude: 70.6693,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]))

        #expect(abs(coordinate.latitude - -33.8688) < 0.0001)
        #expect(abs(coordinate.longitude - -70.6693) < 0.0001)
    }

    @Test func coordinateKeepsSignedValuesWhenReferencesAreMissing() throws {
        // Some writers bake the sign into the value instead of supplying
        // hemisphere references; the value's own sign must survive.
        let coordinate = try #require(PhotoGPSCoordinateExtractor.coordinate(fromGPSDictionary: [
            kCGImagePropertyGPSLatitude: -33.8688,
            kCGImagePropertyGPSLongitude: -70.6693
        ]))

        #expect(abs(coordinate.latitude - -33.8688) < 0.0001)
        #expect(abs(coordinate.longitude - -70.6693) < 0.0001)
    }

    @Test func coordinateReturnsNilWhenLongitudeIsMissing() {
        let coordinate = PhotoGPSCoordinateExtractor.coordinate(fromGPSDictionary: [
            kCGImagePropertyGPSLatitude: 52.3676,
            kCGImagePropertyGPSLatitudeRef: "N"
        ])

        #expect(coordinate == nil)
    }

    @Test func coordinateRejectsNullIslandAsWriterArtifact() {
        let coordinate = PhotoGPSCoordinateExtractor.coordinate(fromGPSDictionary: [
            kCGImagePropertyGPSLatitude: 0.0,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 0.0,
            kCGImagePropertyGPSLongitudeRef: "E"
        ])

        #expect(coordinate == nil)
    }

    @Test func coordinateReturnsNilForOutOfRangeValues() {
        let coordinate = PhotoGPSCoordinateExtractor.coordinate(fromGPSDictionary: [
            kCGImagePropertyGPSLatitude: 91.0,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 4.9041,
            kCGImagePropertyGPSLongitudeRef: "E"
        ])

        #expect(coordinate == nil)
    }

    @Test func coordinateReturnsNilWhenNoGPSMetadataPresent() {
        let data = jpegData()

        #expect(PhotoGPSCoordinateExtractor.coordinate(from: data) == nil)
    }

    @Test func coordinateReturnsNilForInvalidData() {
        let garbage = Data([0x00, 0x01, 0x02])

        #expect(PhotoGPSCoordinateExtractor.coordinate(from: garbage) == nil)
    }
}
