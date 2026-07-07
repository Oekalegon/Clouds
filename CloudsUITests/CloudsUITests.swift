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

        // The flow opens on the sky-conditions step: keep the default
        // cover and move on to the photo step.
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        app.buttons["Start Identification"].tap()

        answerUntilFinished(app)

        XCTAssertTrue(app.buttons["Save Observation"].waitForExistence(timeout: 3))
        app.buttons["Save Observation"].tap()

        XCTAssertFalse(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCloudCoverDialRecordsTappedValue() throws {
        let app = launchApp()

        app.buttons["Identify"].tap()

        let dial = app.descendants(matching: .any)["Cloud cover"].firstMatch
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0/8"].exists)

        // A touch on the ring's right side (a quarter turn) is 2/8.
        dial.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["2/8"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Few clouds"].exists)

        // A stray tap in the middle (on the value label) must not move it.
        dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["2/8"].exists)
    }

    @MainActor
    func testSkyObscuredDisablesDial() throws {
        let app = launchApp()

        app.buttons["Identify"].tap()

        // The button-style Toggle is exposed to accessibility as a switch.
        XCTAssertTrue(app.switches["Sky Obscured"].waitForExistence(timeout: 3))
        app.switches["Sky Obscured"].tap()

        // The dial is replaced by the obscured overlay and Continue still
        // leads on to the photo step.
        XCTAssertTrue(app.staticTexts["Sky obscured"].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSaveAndIdentifyAnotherSkipsSkyConditionsStep() throws {
        let app = launchApp()

        app.buttons["Identify"].tap()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        app.buttons["Start Identification"].tap()
        answerUntilFinished(app)

        XCTAssertTrue(app.buttons["Save & Identify Another Cloud"].waitForExistence(timeout: 3))
        app.buttons["Save & Identify Another Cloud"].tap()

        // The cover was already recorded, so the loop re-enters at the
        // photo step, not the sky-conditions step.
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["How much of the sky is covered?"].exists)
        app.buttons["Start Identification"].tap()
        answerUntilFinished(app)

        XCTAssertTrue(app.buttons["Save Observation"].waitForExistence(timeout: 3))
        app.buttons["Save Observation"].tap()

        XCTAssertFalse(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 2))
    }

    /// Answers "Yes" until the result screen appears. The order/count of
    /// questions isn't hardcoded, since the next question is chosen by
    /// expected information gain, not a fixed sequence. At most 10 question
    /// nodes exist, so this always terminates well within the loop.
    private func answerUntilFinished(_ app: XCUIApplication) {
        for _ in 0..<12 {
            if app.buttons["Save Observation"].waitForExistence(timeout: 3) {
                return
            }
            if app.buttons["Yes"].waitForExistence(timeout: 3) {
                app.buttons["Yes"].tap()
            }
        }
    }
}
