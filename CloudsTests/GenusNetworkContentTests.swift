//
//  GenusNetworkContentTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

/// Validates the real cloud-genus content authored for CLD-7: the network
/// file decodes into a valid `BayesianNetwork`, and every question file
/// matches its corresponding node's states. Reads the JSON straight off
/// disk (relative to this source file) rather than via `Bundle`, since
/// app-startup Bundle loading is CLD-4's concern, not this content's.
///
/// The question set mirrors the decision tree in the WMO cloud
/// identification guide (cloudatlas.wmo.int/en/cloud-identification-guide.html,
/// Figure 10's flowchart diamonds), though each question is modelled here
/// as evidence conditioned only on `Genus` (per CLD-2's engine design)
/// rather than as a rigid sequential traversal.
struct GenusNetworkContentTests {

    private static let resourcesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Clouds/Resources")

    private static let questionNodeIDs = [
        "LightningOrThunder", "BulgingHeapsOrDomes", "FuzzyUpperOutline",
        "UniformLayerNoElements", "SunOrMoonBrightPatch", "ElevatedGreySheet",
        "DenseWetLowerLayer", "WhiteWispyFibres", "ElementSmallerThanOneFinger",
        "ElementOneToThreeFingers"
    ]

    /// Every question must fit an answer-buttons UI without scrolling.
    private static let maxAnswersPerQuestion = 4

    private func decodeNetworkFile() throws -> BayesianNetworkFile {
        let url = Self.resourcesURL.appendingPathComponent("BayesianNetwork/genus-network.json")
        return try JSONDecoder().decode(BayesianNetworkFile.self, from: Data(contentsOf: url))
    }

    private func decodeQuestion(_ id: String) throws -> QuestionDefinition {
        let url = Self.resourcesURL.appendingPathComponent("Questions/\(id).json")
        return try JSONDecoder().decode(QuestionDefinition.self, from: Data(contentsOf: url))
    }

    @Test func genusNetworkFileDecodesAndBuildsAValidNetwork() throws {
        let file = try decodeNetworkFile()
        let network = try file.makeNetwork()

        #expect(network.nodes["Genus"]?.states.count == 10)
        #expect(Set(network.topologicalOrder) == Set(file.nodes.map(\.id)))
    }

    @Test func genusNetworkHasAQuestionNodeForEveryQuestionFile() throws {
        let file = try decodeNetworkFile()
        let networkNodeIDs = Set(file.nodes.map(\.id))

        for id in Self.questionNodeIDs {
            #expect(networkNodeIDs.contains(id))
        }
    }

    @Test func everyQuestionFileValidatesAgainstItsNetworkNodeStates() throws {
        let file = try decodeNetworkFile()
        let nodesByID = Dictionary(uniqueKeysWithValues: file.nodes.map { ($0.id, $0) })

        for id in Self.questionNodeIDs {
            let question = try decodeQuestion(id)
            let node = try #require(nodesByID[id])
            try question.validate(against: node.states)
        }
    }

    @Test func everyQuestionFitsWithinTheAnswerButtonBudget() throws {
        for id in Self.questionNodeIDs {
            let question = try decodeQuestion(id)
            #expect(question.answers.count <= Self.maxAnswersPerQuestion)
        }
    }

    @Test func everyQuestionOffersAnUnsureAnswer() throws {
        for id in Self.questionNodeIDs {
            let question = try decodeQuestion(id)
            #expect(question.answers.contains { $0.id == "Unsure" })
        }
    }

    private func mostLikelyGenus(_ network: BayesianNetwork, given evidence: [NodeID: StateID]) throws -> StateID {
        let posterior = try network.posterior(of: "Genus", given: evidence)
        return try #require(posterior.max(by: { $0.value < $1.value })?.key)
    }

    // Each of the following mirrors one leaf path through the real decision
    // tree dictated by the user, straight off cloud-identification-guide.html.

    @Test func lightningOrThunderYesFavorsCumulonimbus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let genus = try mostLikelyGenus(network, given: ["LightningOrThunder": "Yes"])
        #expect(genus == "Cb")
    }

    @Test func bulgingHeapsWithFuzzyTopFavorsCumulonimbus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "LightningOrThunder": "No",
            "BulgingHeapsOrDomes": "Yes",
            "FuzzyUpperOutline": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cb")
    }

    @Test func bulgingHeapsWithoutFuzzyTopFavorsCumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "LightningOrThunder": "No",
            "BulgingHeapsOrDomes": "Yes",
            "FuzzyUpperOutline": "No"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cu")
    }

    @Test func uniformLayerWithBrightPatchFavorsCirrostratus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "BulgingHeapsOrDomes": "No",
            "UniformLayerNoElements": "Yes",
            "SunOrMoonBrightPatch": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cs")
    }

    @Test func uniformLayerElevatedGreySheetFavorsAltostratus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "UniformLayerNoElements": "Yes",
            "SunOrMoonBrightPatch": "No",
            "ElevatedGreySheet": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "As")
    }

    @Test func uniformLayerDenseWetFavorsNimbostratus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "UniformLayerNoElements": "Yes",
            "SunOrMoonBrightPatch": "No",
            "ElevatedGreySheet": "No",
            "DenseWetLowerLayer": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Ns")
    }

    @Test func uniformLayerNotDenseWetFavorsStratus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "UniformLayerNoElements": "Yes",
            "SunOrMoonBrightPatch": "No",
            "ElevatedGreySheet": "No",
            "DenseWetLowerLayer": "No"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "St")
    }

    @Test func wispyFibresFavorsCirrus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "UniformLayerNoElements": "No",
            "WhiteWispyFibres": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Ci")
    }

    @Test func smallElementsFavorCirrocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "UniformLayerNoElements": "No",
            "WhiteWispyFibres": "No",
            "ElementSmallerThanOneFinger": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cc")
    }

    @Test func oneToThreeFingerElementsFavorAltocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "WhiteWispyFibres": "No",
            "ElementSmallerThanOneFinger": "No",
            "ElementOneToThreeFingers": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Ac")
    }

    @Test func largerElementsFavorStratocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        // Sc, like St, is an elimination leaf with no unique positive
        // marker of its own (Q10's "No" branch) — it only wins once the
        // earlier fork evidence has ruled out the convective/layered
        // genera too, not from the last three answers alone.
        let evidence: [NodeID: StateID] = [
            "BulgingHeapsOrDomes": "No",
            "UniformLayerNoElements": "No",
            "WhiteWispyFibres": "No",
            "ElementSmallerThanOneFinger": "No",
            "ElementOneToThreeFingers": "No"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Sc")
    }
}
