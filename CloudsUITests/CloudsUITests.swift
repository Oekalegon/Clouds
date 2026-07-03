//
//  CloudsUITests.swift
//  CloudsUITests
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import XCTest

final class CloudsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddAndDeleteItem() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Add Item"].tap()
        XCTAssertEqual(app.cells.count, 1)
    }
}
