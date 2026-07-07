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
}
