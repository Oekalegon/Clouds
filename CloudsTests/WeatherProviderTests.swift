//
//  WeatherProviderTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 06/07/2026.
//

import Foundation
import Testing
@testable import Clouds

struct WeatherProviderTests {
    private let now = Date(timeIntervalSinceReferenceDate: 0)

    @Test func isEligibleWhenNoPhotoDate() {
        #expect(WeatherProvider.isEligible(photoDate: nil, now: now))
    }

    @Test func isEligibleForRecentLibraryPhoto() {
        let photoDate = now.addingTimeInterval(-5 * 60)
        #expect(WeatherProvider.isEligible(photoDate: photoDate, now: now))
    }

    @Test func isEligibleAtExactlyFifteenMinutes() {
        let photoDate = now.addingTimeInterval(-15 * 60)
        #expect(WeatherProvider.isEligible(photoDate: photoDate, now: now))
    }

    @Test func isNotEligibleForOldLibraryPhoto() {
        let photoDate = now.addingTimeInterval(-20 * 60)
        #expect(!WeatherProvider.isEligible(photoDate: photoDate, now: now))
    }
}
