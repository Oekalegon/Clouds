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

    /// Launches with an isolated in-memory store so each test starts
    /// empty, regardless of what earlier tests in this run saved.
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING-RESET"]
        app.launch()
        return app
    }

    @MainActor
    func testEmptyStateShowsWhenNoObservations() throws {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIdentifyFlowSavesAnObservationToHistory() throws {
        let app = launchApp()

        app.buttons["Identify"].tap()

        // Answer through the flow (order/count of questions isn't
        // hardcoded, since the next question is chosen by expected
        // information gain, not a fixed sequence). At most 10 question
        // nodes exist, so this always terminates well within the loop.
        for _ in 0..<12 {
            if app.buttons["Save Observation"].waitForExistence(timeout: 3) {
                break
            }
            if app.buttons["Yes"].waitForExistence(timeout: 3) {
                app.buttons["Yes"].tap()
            }
        }

        XCTAssertTrue(app.buttons["Save Observation"].waitForExistence(timeout: 3))
        app.buttons["Save Observation"].tap()

        XCTAssertFalse(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 2))
    }
}
