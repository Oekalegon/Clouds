//
//  IdentificationCatalogTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

struct IdentificationCatalogTests {

    /// Same technique as `GenusNetworkContentTests`: read the real,
    /// production JSON straight off disk (not via `Bundle`, since this
    /// unit-test target isn't app-hosted) to get real regression coverage
    /// of the pure assembly initializer.
    private static let resourcesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Clouds/Resources")

    private func loadRealCatalog() throws -> IdentificationCatalog {
        let decoder = JSONDecoder()

        let networkURL = Self.resourcesURL.appendingPathComponent("BayesianNetwork/genus-network.json")
        let networkFile = try decoder.decode(BayesianNetworkFile.self, from: Data(contentsOf: networkURL))

        let questionIDs = networkFile.nodes.map(\.id).filter { $0 != "Genus" }
        let questionFiles: [QuestionDefinition] = questionIDs.compactMap { id in
            let url = Self.resourcesURL.appendingPathComponent("Questions/\(id).json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(QuestionDefinition.self, from: data)
        }

        return try IdentificationCatalog(networkFile: networkFile, questionFiles: questionFiles)
    }

    /// Regression guard: the very first `bestNextQuestion` call (zero
    /// evidence, all 10 candidates) once took 222s in a debug build
    /// before `BayesianNetwork.jointPosterior` pruned barren nodes out of
    /// its enumeration — this should now be near-instant. A generous
    /// 2-second bound leaves headroom for slow CI machines while still
    /// catching a reintroduced combinatorial blow-up by orders of
    /// magnitude.
    @Test func firstBestNextQuestionStaysFast() throws {
        let catalog = try loadRealCatalog()
        let start = Date()
        _ = try catalog.network.bestNextQuestion(among: catalog.questionNodeIDs, forTargets: ["Genus"], given: [:])
        #expect(Date().timeIntervalSince(start) < 2.0)
    }

    @Test func realContentAssemblesIntoAValidCatalog() throws {
        let catalog = try loadRealCatalog()

        #expect(catalog.network.nodes["Genus"]?.states.count == 10)
        #expect(catalog.questionNodeIDs.count == 18)
        #expect(!catalog.questionNodeIDs.contains("Genus"))
        #expect(!catalog.questionNodeIDs.contains("LightningThunderAssociated"))
        #expect(Set(catalog.questions.keys) == Set(catalog.questionNodeIDs))
    }

    @Test func throwsWhenAQuestionHasNoMatchingNode() throws {
        let networkFile = try JSONDecoder().decode(BayesianNetworkFile.self, from: Data("""
        {
          "nodes": [
            { "id": "Genus", "states": ["Cb", "Cu"], "cpt": [{ "distribution": { "Cb": 0.5, "Cu": 0.5 } }] }
          ]
        }
        """.utf8))

        let orphanQuestion = QuestionDefinition(
            id: "NoSuchNode",
            text: "Does this match anything?",
            description: nil,
            image: nil,
            answers: [QuestionAnswer(id: "Yes", label: "Yes"), QuestionAnswer(id: "No", label: "No")]
        )

        #expect(throws: IdentificationCatalogError.missingResource("NoSuchNode")) {
            try IdentificationCatalog(networkFile: networkFile, questionFiles: [orphanQuestion])
        }
    }

    @Test func propagatesAnswerStateMismatchFromQuestionValidation() throws {
        let networkFile = try JSONDecoder().decode(BayesianNetworkFile.self, from: Data("""
        {
          "nodes": [
            { "id": "Genus", "states": ["Cb", "Cu"], "cpt": [{ "distribution": { "Cb": 0.5, "Cu": 0.5 } }] },
            {
              "id": "SomeQuestion", "states": ["Yes", "No"], "parents": ["Genus"],
              "cpt": [
                { "given": { "Genus": "Cb" }, "distribution": { "Yes": 0.5, "No": 0.5 } },
                { "given": { "Genus": "Cu" }, "distribution": { "Yes": 0.5, "No": 0.5 } }
              ]
            }
          ]
        }
        """.utf8))

        let mismatchedQuestion = QuestionDefinition(
            id: "SomeQuestion",
            text: "Does this match?",
            description: nil,
            image: nil,
            answers: [QuestionAnswer(id: "Yes", label: "Yes"), QuestionAnswer(id: "Maybe", label: "Maybe")]
        )

        #expect(throws: SchemaError.self) {
            try IdentificationCatalog(networkFile: networkFile, questionFiles: [mismatchedQuestion])
        }
    }
}
