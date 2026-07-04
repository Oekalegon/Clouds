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
    }

    @Test func sectionKeyIsEqualForSameDay() async throws {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: .now)!
        #expect(CloudObservation.sectionKey(for: morning) == CloudObservation.sectionKey(for: evening))
    }

    @Test func sectionKeyDiffersForDifferentDays() async throws {
        let calendar = Calendar.current
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        #expect(CloudObservation.sectionKey(for: today) != CloudObservation.sectionKey(for: yesterday))
    }
}
