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
        // leads on to the questions. The first question the session asks
        // isn't necessarily Yes/No (e.g. it may be "Shading"), so this
        // only checks that some known question — or the result screen —
        // was reached, not which one.
        XCTAssertTrue(app.staticTexts["Sky obscured"].waitForExistence(timeout: 2))
        app.buttons["Continue"].tap()
        XCTAssertTrue(waitForQuestionOrSaveButton(app, timeout: 5))
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

    /// The answer that steers toward Nimbostratus for every real question
    /// node in the bundled genus network — sampled once via
    /// `IdentificationSessionTests`'s `groundTruth(trueGenus:network:)`
    /// helper against the same content this app ships, then hardcoded
    /// here since this UI test target can't import the engine directly.
    /// Not every question is Yes/No (e.g. `Shading`, `ElementSize`), so a
    /// fixed set of answer-button identifiers to tap by node id is needed
    /// rather than a blanket "tap Yes". If this ever drifts from the real
    /// CPTs, `endToEndSessionIdentifiesTheTrueGenusFromTruthfulAnswers`
    /// (genus: .nimbostratus) in `IdentificationSessionTests` catches it
    /// first — this table just needs re-sampling from that same helper.
    private static let nimbostratusAnswers: [String: String] = [
        "Arcus": "No", "Asperitas": "No", "Cauda": "No", "Cavum": "No",
        "DiffuseBase": "Yes", "ElementSize": "LessThanOneDegree", "Fibrous": "Yes",
        "FlattenedBase": "No", "Fluctus": "No", "Flumen": "No", "Granular": "No",
        "HasDistinctElements": "No", "HookOrTuft": "No", "Incus": "No",
        "LightningSeen": "No", "Mamma": "No", "Murus": "No",
        "OpticalThickness": "Opaque", "Pannus": "Yes", "Pileus": "No",
        "Precipitation": "Uniform", "Ragged": "No", "Shading": "FullyShaded",
        "Sheaves": "No", "SilkySheen": "Yes", "SpreadAsVeil": "Yes",
        "ThinFilaments": "No", "ThunderHeard": "No", "Tuba": "No",
        "Undulated": "No", "UniformBase": "Yes", "Velum": "No",
        "VerticalDevelopment": "No", "Virga": "Yes"
    ]

    /// True once either a known question node (by its title's accessibility
    /// identifier) or the "Save Observation" button appears — for callers
    /// that only care whether the Q&A phase was reached, not which
    /// question came first.
    private func waitForQuestionOrSaveButton(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["Save Observation"].exists { return true }
            if Self.nimbostratusAnswers.keys.contains(where: { app.staticTexts[$0].exists }) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    /// Answers whichever question the session actually asks (adaptive, by
    /// expected information gain — not a fixed order, and not every node
    /// gets asked once earlier answers make it inapplicable) with the
    /// answer that leads to Nimbostratus, identified by the question
    /// title's accessibility identifier (the node id) rather than by
    /// label text, since several questions aren't Yes/No.
    private func answerUntilFinished(_ app: XCUIApplication) {
        for _ in 0..<(Self.nimbostratusAnswers.count + 5) {
            if app.buttons["Save Observation"].waitForExistence(timeout: 3) {
                return
            }
            guard let questionID = Self.nimbostratusAnswers.keys.first(where: { app.staticTexts[$0].exists }) else {
                continue
            }
            let answerID = Self.nimbostratusAnswers[questionID] ?? "No"
            if app.buttons[answerID].exists {
                app.buttons[answerID].tap()
            }
        }
    }
}
