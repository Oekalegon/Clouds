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

        // Photo step first; without a photo the session is in-the-moment,
        // so the sky-conditions step follows.
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        app.buttons["Start Identification"].tap()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        answerUntilFinished(app)

        XCTAssertTrue(app.buttons["Save Observation"].waitForExistence(timeout: 3))
        app.buttons["Save Observation"].tap()

        // Saving lands on the sky-condition summary, not back in history.
        XCTAssertTrue(app.buttons["Add Another Observation"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        XCTAssertFalse(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCloudCoverDialRecordsTappedValue() throws {
        let app = launchApp()

        app.buttons["Identify"].tap()
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        app.buttons["Start Identification"].tap()

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
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        app.buttons["Start Identification"].tap()

        // The button-style Toggle is exposed to accessibility as a switch.
        XCTAssertTrue(app.switches["Sky Obscured"].waitForExistence(timeout: 3))
        app.switches["Sky Obscured"].tap()

        // The dial is replaced by the obscured overlay and Continue still
        // leads on to the questions.
        XCTAssertTrue(app.staticTexts["Sky obscured"].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()
        XCTAssertTrue(
            app.buttons["Yes"].waitForExistence(timeout: 5) ||
            app.buttons["Save Observation"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testAddingAnotherObservationSharesTheSkyCondition() throws {
        let app = launchApp()

        app.buttons["Identify"].tap()
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        app.buttons["Start Identification"].tap()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()
        answerUntilFinished(app)

        XCTAssertTrue(app.buttons["Save Observation"].waitForExistence(timeout: 3))
        app.buttons["Save Observation"].tap()

        // The summary lists the first saved observation. Counting is done
        // via the rows' accessibility identifier, since bare `app.cells`
        // also matches the history list behind the sheet.
        XCTAssertTrue(app.buttons["Add Another Observation"].waitForExistence(timeout: 3))
        XCTAssertEqual(summaryRows(app).count, 1)
        app.buttons["Add Another Observation"].tap()

        // Second observation re-enters at the photo step; the cover was
        // already recorded, so the questions follow directly.
        XCTAssertTrue(app.buttons["Start Identification"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["How much of the sky is covered?"].exists)
        app.buttons["Start Identification"].tap()
        answerUntilFinished(app)

        XCTAssertTrue(app.buttons["Save Observation"].waitForExistence(timeout: 3))
        app.buttons["Save Observation"].tap()

        // Back on the summary with both observations under the same sky.
        XCTAssertTrue(app.buttons["Add Another Observation"].waitForExistence(timeout: 3))
        XCTAssertTrue(summaryRows(app).element(boundBy: 1).waitForExistence(timeout: 3))
        XCTAssertEqual(summaryRows(app).count, 2)
        app.buttons["Done"].tap()

        XCTAssertFalse(app.staticTexts["No Observations Yet"].waitForExistence(timeout: 2))
    }

    /// The saved observations shown on the sky-condition summary screen,
    /// counted by their genus headline ("Yes" to everything always yields
    /// Nimbostratus) inside the summary's own list — the history list
    /// behind the sheet stays in the accessibility tree, so unscoped
    /// queries would match its rows and section headers too.
    private func summaryRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.collectionViews["SummaryObservationsList"].staticTexts.matching(identifier: "Nimbostratus")
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
