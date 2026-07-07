//
//  HistoryEntryTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Foundation
import SwiftData
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

    /// Runs the exact predicate HistoryView's standalone query uses:
    /// relationship-to-nil predicates are a quirky corner of SwiftData, and
    /// if this one ever matched linked observations too, history would show
    /// them twice.
    @Test func standalonePredicateExcludesSkyLinkedObservations() throws {
        let container = try ModelContainer(
            for: CloudObservation.self, SkyConditions.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let conditions = SkyConditions()
        context.insert(conditions)
        context.insert(CloudObservation(genus: "Cumulus", skyConditions: conditions))
        context.insert(CloudObservation(genus: "Cirrus"))
        try context.save()

        let standalone = try context.fetch(
            FetchDescriptor(predicate: CloudObservation.standalonePredicate)
        )

        #expect(standalone.count == 1)
        #expect(standalone.first?.genus == "Cirrus")
    }
}
