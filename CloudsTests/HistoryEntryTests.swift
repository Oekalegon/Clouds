//
//  HistoryEntryTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Foundation
import Testing
@testable import Clouds

struct HistoryEntryTests {
    private let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func chronologicalIsEmptyForNoInput() {
        #expect(HistoryEntry.chronological(skyConditions: [], standaloneObservations: []).isEmpty)
    }

    @Test func chronologicalInterleavesBothKindsMostRecentFirst() {
        let oldObservation = CloudObservation(date: base)
        let conditions = SkyConditions(date: base.addingTimeInterval(3600))
        let newObservation = CloudObservation(date: base.addingTimeInterval(7200))

        let entries = HistoryEntry.chronological(
            skyConditions: [conditions],
            standaloneObservations: [oldObservation, newObservation]
        )

        #expect(entries.count == 3)
        #expect(entries.map(\.date) == [
            base.addingTimeInterval(7200),
            base.addingTimeInterval(3600),
            base
        ])
        guard case .observation = entries[0], case .skyConditions = entries[1], case .observation = entries[2] else {
            Issue.record("Entries are not of the expected kinds: \(entries)")
            return
        }
    }

    @Test func chronologicalKeepsSkyConditionsAsSingleEntries() {
        let conditions = SkyConditions(date: base)
        let entries = HistoryEntry.chronological(skyConditions: [conditions], standaloneObservations: [])
        #expect(entries.count == 1)
    }
}
