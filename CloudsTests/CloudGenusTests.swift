//
//  CloudGenusTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
@testable import Clouds

struct CloudGenusTests {

    @Test func allCasesRoundTripThroughRawValue() {
        for genus in CloudGenus.allCases {
            #expect(CloudGenus(rawValue: genus.rawValue) == genus)
        }
    }

    @Test func allCasesHaveANonEmptyDisplayName() {
        for genus in CloudGenus.allCases {
            #expect(!genus.displayName.isEmpty)
        }
    }

    @Test func thereAreExactlyTenGenera() {
        #expect(CloudGenus.allCases.count == 10)
    }
}
