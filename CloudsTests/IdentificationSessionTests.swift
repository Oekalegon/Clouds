//
//  IdentificationSessionTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

@MainActor
struct IdentificationSessionTests {

    /// Genus(A,B; uniform prior) + two Yes/No questions, neither of which
    /// alone crosses the default 0.9 confidence threshold
    /// (P(A|Q1=Yes)=0.85, P(A|Q2=Yes)=0.65), but jointly do (≈0.913).
    /// Deliberately doesn't assume which one `bestNextQuestion` asks
    /// first — that's the engine's call based on expected information
    /// gain, not something this test should hardcode.
    private static let twoQuestionNetworkJSON = """
    {
      "nodes": [
        { "id": "Genus", "states": ["A", "B"], "cpt": [{ "distribution": { "A": 0.5, "B": 0.5 } }] },
        {
          "id": "Q1", "states": ["Yes", "No"], "parents": ["Genus"],
          "cpt": [
            { "given": { "Genus": "A" }, "distribution": { "Yes": 0.85, "No": 0.15 } },
            { "given": { "Genus": "B" }, "distribution": { "Yes": 0.15, "No": 0.85 } }
          ]
        },
        {
          "id": "Q2", "states": ["Yes", "No"], "parents": ["Genus"],
          "cpt": [
            { "given": { "Genus": "A" }, "distribution": { "Yes": 0.65, "No": 0.35 } },
            { "given": { "Genus": "B" }, "distribution": { "Yes": 0.35, "No": 0.65 } }
          ]
        }
      ]
    }
    """

    /// Genus(A,B; uniform prior) + Q1 (near-deterministic, so it's always
    /// picked first) + Q2, which is almost never applicable when Genus=A
    /// (P(NotApplicable|A)=0.95) but very informative when Genus=B. Q2's
    /// own NotApplicable-vs-not split is itself informative about Genus,
    /// so Q1 must be sharp enough to still win the initial expected
    /// information gain comparison. Mirrors CLD-8: a question whose
    /// real-world relevance depends on which genus the evidence currently
    /// favors.
    private static let notApplicableNetworkJSON = """
    {
      "nodes": [
        { "id": "Genus", "states": ["A", "B"], "cpt": [{ "distribution": { "A": 0.5, "B": 0.5 } }] },
        {
          "id": "Q1", "states": ["Yes", "No"], "parents": ["Genus"],
          "cpt": [
            { "given": { "Genus": "A" }, "distribution": { "Yes": 0.99, "No": 0.01 } },
            { "given": { "Genus": "B" }, "distribution": { "Yes": 0.01, "No": 0.99 } }
          ]
        },
        {
          "id": "Q2", "states": ["Yes", "No", "NotApplicable"], "parents": ["Genus"],
          "cpt": [
            { "given": { "Genus": "A" }, "distribution": { "Yes": 0.025, "No": 0.025, "NotApplicable": 0.95 } },
            { "given": { "Genus": "B" }, "distribution": { "Yes": 0.9, "No": 0.05, "NotApplicable": 0.05 } }
          ]
        }
      ]
    }
    """

    /// Genus(A,B) + a single question whose "Unsure" answer is equally
    /// likely under both genera, so the posterior stays a perfect tie.
    private static let tieBreakNetworkJSON = """
    {
      "nodes": [
        { "id": "Genus", "states": ["A", "B"], "cpt": [{ "distribution": { "A": 0.5, "B": 0.5 } }] },
        {
          "id": "Q1", "states": ["Yes", "No", "Unsure"], "parents": ["Genus"],
          "cpt": [
            { "given": { "Genus": "A" }, "distribution": { "Yes": 0.45, "No": 0.45, "Unsure": 0.1 } },
            { "given": { "Genus": "B" }, "distribution": { "Yes": 0.45, "No": 0.45, "Unsure": 0.1 } }
          ]
        }
      ]
    }
    """

    private func question(_ id: NodeID, states: [StateID]) -> QuestionDefinition {
        QuestionDefinition(
            id: id,
            text: "Question \(id)?",
            description: nil,
            image: nil,
            answers: states.map { QuestionAnswer(id: $0, label: $0) }
        )
    }

    private func makeCatalog(json: String, questionStates: [(NodeID, [StateID])]) throws -> IdentificationCatalog {
        let networkFile = try JSONDecoder().decode(BayesianNetworkFile.self, from: Data(json.utf8))
        let questions = questionStates.map { question($0.0, states: $0.1) }
        return try IdentificationCatalog(networkFile: networkFile, questionFiles: questions)
    }

    private func twoQuestionSession(confidenceThreshold: Double = 0.9) throws -> IdentificationSession {
        let catalog = try makeCatalog(
            json: Self.twoQuestionNetworkJSON,
            questionStates: [("Q1", ["Yes", "No"]), ("Q2", ["Yes", "No"])]
        )
        return IdentificationSession(catalog: catalog, confidenceThreshold: confidenceThreshold)
    }

    @Test func startComputesAFirstQuestionWithoutAnyEvidence() async throws {
        let session = try twoQuestionSession()
        await session.start()

        #expect(session.currentQuestionID != nil)
        #expect(session.history.isEmpty)
        #expect(!session.canGoBack)
        #expect(!session.isFinished)
    }

    @Test func answeringBothQuestionsReachesAConfidentFinish() async throws {
        let session = try twoQuestionSession()
        await session.start()

        let first = try #require(session.currentQuestionID)
        await session.selectAnswer("Yes")
        let second = try #require(session.currentQuestionID)
        #expect(Set([first, second]) == Set(["Q1", "Q2"]))

        await session.selectAnswer("Yes")

        #expect(session.isFinished)
        #expect(session.mostLikelyGenus == "A")
        #expect((session.posterior["A"] ?? 0) > 0.9)
    }

    @Test func goBackReturnsToThePreviousQuestionWithItsAnswer() async throws {
        let session = try twoQuestionSession()
        await session.start()
        let first = try #require(session.currentQuestionID)
        await session.selectAnswer("Yes")
        _ = try #require(session.currentQuestionID)

        await session.goBack()

        #expect(session.currentQuestionID == first)
        #expect(session.currentAnswer == "Yes")
        #expect(!session.isFinished)
    }

    @Test func reselectingTheSameAnswerDoesNotTruncateForwardHistory() async throws {
        let session = try twoQuestionSession()
        await session.start()
        let first = try #require(session.currentQuestionID)
        await session.selectAnswer("Yes")
        await session.selectAnswer("Yes")
        try #require(session.isFinished)

        await session.goBack()
        await session.goBack()
        try #require(session.currentQuestionID == first)

        // Re-answering with the same value should preserve the second
        // question's recorded answer.
        await session.selectAnswer("Yes")

        #expect(session.history.count == 2)
        #expect(session.canGoForward)
    }

    @Test func changingAnAnswerTruncatesForwardHistory() async throws {
        let session = try twoQuestionSession()
        await session.start()
        let first = try #require(session.currentQuestionID)
        await session.selectAnswer("Yes")
        await session.selectAnswer("Yes")
        try #require(session.isFinished)

        await session.goBack()
        await session.goBack()
        try #require(session.currentQuestionID == first)

        await session.selectAnswer("No")

        #expect(session.history.count == 1)
        #expect(session.history[0].answer == "No")
    }

    @Test func stopsViaExhaustionWhenThresholdIsUnreachable() async throws {
        let catalog = try makeCatalog(json: Self.twoQuestionNetworkJSON, questionStates: [("Q1", ["Yes", "No"]), ("Q2", ["Yes", "No"])])
        let session = IdentificationSession(catalog: catalog, confidenceThreshold: 0.999)
        await session.start()

        await session.selectAnswer("Yes")
        await session.selectAnswer("Yes")

        // Both questions have been asked; even below threshold, there are
        // no more candidates, so the session must still terminate.
        #expect(session.isFinished)
        #expect(session.currentQuestionID == nil)
    }

    @Test func skipsACandidateWhoseNotApplicableLikelihoodIsHigh() async throws {
        let catalog = try makeCatalog(
            json: Self.notApplicableNetworkJSON,
            questionStates: [("Q1", ["Yes", "No"]), ("Q2", ["Yes", "No"])]
        )
        // A high confidence threshold keeps the session from finishing on
        // confidence alone, isolating the NotApplicable-driven skip.
        let session = IdentificationSession(catalog: catalog, confidenceThreshold: 0.999, notApplicableThreshold: 0.8)
        await session.start()

        try #require(session.currentQuestionID == "Q1")
        await session.selectAnswer("Yes")

        // P(A | Q1=Yes) = 0.99, so P(NotApplicable) for Q2 is
        // 0.99*0.95 + 0.01*0.05 ≈ 0.941 — above the 0.8 threshold, so Q2
        // must be skipped rather than asked, even though it's the only
        // remaining candidate and confidence (0.99 < 0.999) hasn't been
        // reached.
        #expect(session.isFinished)
        #expect(session.currentQuestionID == nil)
    }

    @Test func tiedPosteriorPicksTheGenusDeclaredFirst() async throws {
        let catalog = try makeCatalog(json: Self.tieBreakNetworkJSON, questionStates: [("Q1", ["Yes", "No", "Unsure"])])
        let session = IdentificationSession(catalog: catalog, confidenceThreshold: 0.9)
        await session.start()

        try #require(session.currentQuestionID == "Q1")
        await session.selectAnswer("Unsure")

        #expect(session.isFinished)
        #expect(session.mostLikelyGenus == "A")
        #expect(session.posterior["A"] == session.posterior["B"])
    }

    // MARK: - End-to-end sessions against the real bundled content

    /// Same technique as `IdentificationCatalogTests`/`GenusNetworkContentTests`:
    /// read the real, production JSON straight off disk rather than via
    /// `Bundle`, since this unit-test target isn't app-hosted.
    private static let resourcesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Clouds/Resources")

    private func loadRealCatalog() throws -> IdentificationCatalog {
        let decoder = JSONDecoder()

        let networkURL = Self.resourcesURL.appendingPathComponent("BayesianNetwork/genus-network.json")
        let networkFile = try decoder.decode(BayesianNetworkFile.self, from: Data(contentsOf: networkURL))

        let questionIDs = networkFile.nodes.map(\.id).filter { $0 != "Genus" }
        let questionFiles = try questionIDs.map { id in
            try decoder.decode(
                QuestionDefinition.self,
                from: Data(contentsOf: Self.resourcesURL.appendingPathComponent("Questions/\(id).json"))
            )
        }

        return try IdentificationCatalog(networkFile: networkFile, questionFiles: questionFiles)
    }

    /// A truthful "user" for `trueGenus`: whichever real (non-NotApplicable)
    /// answer is most likely for that genus on the asked question, straight
    /// from the network's own CPT — never the answer a fixed tree-order
    /// walk would give, since `bestNextQuestion` doesn't respect tree order.
    private func oracleAnswer(for questionID: NodeID, trueGenus: StateID, network: BayesianNetwork) -> StateID {
        let distribution = network.cpts[questionID]?.distribution(givenParents: Assignment(["Genus": trueGenus])) ?? [:]
        let realAnswers = distribution.filter { $0.key != QuestionDefinition.notApplicableStateID }
        return realAnswers.max { $0.value < $1.value }?.key ?? "Unsure"
    }

    private func runSessionToCompletion(catalog: IdentificationCatalog, trueGenus: StateID) async -> IdentificationSession {
        let session = IdentificationSession(catalog: catalog)
        await session.start()

        while !session.isFinished, let questionID = session.currentQuestionID {
            let answer = oracleAnswer(for: questionID, trueGenus: trueGenus, network: catalog.network)
            await session.selectAnswer(answer)
        }

        return session
    }

    /// End-to-end regression guard: for each real genus, a "user" who
    /// truthfully answers whatever question `bestNextQuestion` actually
    /// asks (not a fixed tree-order walk) should end up with that genus as
    /// `mostLikelyGenus`. This is the test that would have caught CLD-8's
    /// NotApplicable-calibration bug, where genera with a short
    /// "applicable" question set (Ci, Cs, Cu, Cb) get systematically
    /// misclassified once a real answer's likelihood is distorted by the
    /// per-genus NotApplicable rescaling.
    ///
    /// Those four genera are wrapped in `withKnownIssue` rather than fixed
    /// here: the real fix is an engine-level renormalization (or a full
    /// Bayesian-network restructuring), tracked as separate follow-up work.
    /// `withKnownIssue` will itself fail once that fix lands and one of
    /// these starts passing — that's the signal to remove it from this set.
    @Test(arguments: CloudGenus.allCases)
    func endToEndSessionIdentifiesTheTrueGenusFromTruthfulAnswers(genus: CloudGenus) async throws {
        let knownlyMiscalibrated: Set<CloudGenus> = [.cirrus, .cirrostratus, .cumulus, .cumulonimbus]
        let catalog = try loadRealCatalog()
        let session = await runSessionToCompletion(catalog: catalog, trueGenus: genus.rawValue)

        if knownlyMiscalibrated.contains(genus) {
            withKnownIssue("CLD-8's NotApplicable calibration misclassifies this genus under adaptive question selection; tracked for the planned Bayesian network restructuring") {
                #expect(session.mostLikelyGenus == genus.rawValue)
            }
        } else {
            #expect(session.mostLikelyGenus == genus.rawValue)
        }
    }
}
