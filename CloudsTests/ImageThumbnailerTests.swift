//
//  ImageThumbnailerTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import Testing
import UIKit
@testable import Clouds

struct ImageThumbnailerTests {

    private func jpegData(width: Int, height: Int) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 1.0)!
    }

    @Test func downsampledJPEGDataShrinksALargerImageToTheMaxPixelSize() throws {
        let original = jpegData(width: 1200, height: 900)

        let thumbnail = try #require(ImageThumbnailer.downsampledJPEGData(from: original, maxPixelSize: 300))

        let image = try #require(UIImage(data: thumbnail))
        #expect(max(image.size.width, image.size.height) <= 300)
        #expect(thumbnail.count < original.count)
    }

    @Test func downsampledJPEGDataPreservesAspectRatio() throws {
        let original = jpegData(width: 1200, height: 600)

        let thumbnail = try #require(ImageThumbnailer.downsampledJPEGData(from: original, maxPixelSize: 300))
        let image = try #require(UIImage(data: thumbnail))

        #expect(image.size.width == 300)
        #expect(image.size.height == 150)
    }

    @Test func downsampledJPEGDataReturnsNilForInvalidData() {
        let garbage = Data([0x00, 0x01, 0x02])

        #expect(ImageThumbnailer.downsampledJPEGData(from: garbage, maxPixelSize: 300) == nil)
    }
}
