//
//  CloudsTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import Testing
import Foundation
@testable import Clouds

struct CloudsTests {

    @Test func newObservationHasNilOptionalFields() async throws {
        let observation = CloudObservation()
        #expect(observation.latitude == nil)
        #expect(observation.longitude == nil)
        #expect(observation.genus == nil)
        #expect(observation.species == nil)
        #expect(observation.variety == nil)
        #expect(observation.supplementaryFeatures.isEmpty)
        #expect(observation.accessoryClouds.isEmpty)
        #expect(observation.photoData == nil)
        #expect(observation.thumbnailData == nil)
        #expect(observation.skyConditions == nil)
    }

    @Test func observationKeepsSupplementaryFeaturesAndAccessoryCloudsSeparate() async throws {
        let observation = CloudObservation(
            supplementaryFeatures: ["Mamma", "Arcus"],
            accessoryClouds: ["Pileus", "Velum"]
        )
        #expect(observation.supplementaryFeatures == ["Mamma", "Arcus"])
        #expect(observation.accessoryClouds == ["Pileus", "Velum"])
    }
}
