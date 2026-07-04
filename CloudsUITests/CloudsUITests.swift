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
    func testEmptyStateShowsWhenNoObservations() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIdentifyButtonShowsComingSoonPlaceholder() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Identify"].tap()
        XCTAssertTrue(app.staticTexts["Coming Soon"].waitForExistence(timeout: 5))
    }
}
