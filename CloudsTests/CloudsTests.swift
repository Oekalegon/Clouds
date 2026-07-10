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
        #expect(observation.specialFeature == nil)
        #expect(observation.photoData == nil)
        #expect(observation.thumbnailData == nil)
        #expect(observation.skyConditions == nil)
    }

    @Test func specialFeatureTextIsNilWhenNothingDetected() async throws {
        #expect(CloudObservation.specialFeatureText(supplementaryFeatures: [], accessoryClouds: []) == nil)
    }

    @Test func specialFeatureTextJoinsOnlySupplementaryFeatures() async throws {
        let text = CloudObservation.specialFeatureText(supplementaryFeatures: ["Mamma", "Arcus"], accessoryClouds: [])
        #expect(text == "Mamma, Arcus")
    }

    @Test func specialFeatureTextJoinsOnlyAccessoryClouds() async throws {
        let text = CloudObservation.specialFeatureText(supplementaryFeatures: [], accessoryClouds: ["Pileus"])
        #expect(text == "Pileus")
    }

    @Test func specialFeatureTextJoinsSupplementaryFeaturesBeforeAccessoryClouds() async throws {
        let text = CloudObservation.specialFeatureText(
            supplementaryFeatures: ["Mamma", "Arcus"],
            accessoryClouds: ["Pileus", "Velum"]
        )
        #expect(text == "Mamma, Arcus, Pileus, Velum")
    }
}
