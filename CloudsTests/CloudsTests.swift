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

    @Test func itemStoresTimestamp() async throws {
        let timestamp = Date()
        let item = Item(timestamp: timestamp)
        #expect(item.timestamp == timestamp)
    }
}
