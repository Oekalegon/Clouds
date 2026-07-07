//
//  SkyConditionsTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Foundation
import SwiftData
import Testing
@testable import Clouds

struct SkyConditionsTests {
    @Test func cloudCoverDescriptionIsNilWhenNothingRecorded() {
        #expect(SkyConditions().cloudCoverDescription == nil)
    }

    @Test func cloudCoverDescriptionShowsEighths() {
        #expect(SkyConditions(cloudCoverEighths: 3).cloudCoverDescription == "3/8")
        #expect(SkyConditions(cloudCoverEighths: 0).cloudCoverDescription == "0/8")
        #expect(SkyConditions(cloudCoverEighths: 8).cloudCoverDescription == "8/8")
    }

    @Test func cloudCoverDescriptionPrefersObscured() {
        let conditions = SkyConditions(cloudCoverEighths: 3, isSkyObscured: true)
        #expect(conditions.cloudCoverDescription == "Sky obscured")
    }

    @Test func coverNamesFollowOktaBuckets() {
        #expect(SkyConditions.coverName(forEighths: 0) == "Clear")
        #expect(SkyConditions.coverName(forEighths: 1) == "Few clouds")
        #expect(SkyConditions.coverName(forEighths: 2) == "Few clouds")
        #expect(SkyConditions.coverName(forEighths: 3) == "Scattered clouds")
        #expect(SkyConditions.coverName(forEighths: 4) == "Scattered clouds")
        #expect(SkyConditions.coverName(forEighths: 5) == "Broken clouds")
        #expect(SkyConditions.coverName(forEighths: 7) == "Broken clouds")
        #expect(SkyConditions.coverName(forEighths: 8) == "Overcast")
    }

    @Test func multipleObservationsShareOneSkyConditions() throws {
        let context = try makeInMemoryContext()
        let conditions = SkyConditions(cloudCoverEighths: 5)
        context.insert(conditions)
        let cumulus = CloudObservation(genus: "Cumulus", skyConditions: conditions)
        let cirrus = CloudObservation(genus: "Cirrus", skyConditions: conditions)
        context.insert(cumulus)
        context.insert(cirrus)
        try context.save()

        #expect(conditions.observations.count == 2)
        #expect(cumulus.skyConditions?.cloudCoverEighths == 5)
        #expect(cirrus.skyConditions === cumulus.skyConditions)
    }

    @Test func deletingSkyConditionsNullifiesObservations() throws {
        let context = try makeInMemoryContext()
        let conditions = SkyConditions(cloudCoverEighths: 2)
        context.insert(conditions)
        let observation = CloudObservation(genus: "Stratus", skyConditions: conditions)
        context.insert(observation)
        try context.save()

        context.delete(conditions)
        try context.save()

        #expect(observation.skyConditions == nil)
        #expect(observation.genus == "Stratus")
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: CloudObservation.self, SkyConditions.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
