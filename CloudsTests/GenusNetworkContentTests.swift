//
//  GenusNetworkContentTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

/// Validates the real cloud-genus content authored for CLD-9: the network
/// file decodes into a valid `BayesianNetwork`, and every question file
/// matches its corresponding node's states. Reads the JSON straight off
/// disk (relative to this source file) rather than via `Bundle`, since
/// app-startup Bundle loading is CLD-4's concern, not this content's.
///
/// This content supersedes CLD-7's flowchart-only tree: it's modelled on
/// the WMO Tabular Guide's Essential/Usual/Possible feature ratings
/// (cloudatlas.wmo.int/en/tabular-guide-genus.html), most questions
/// conditioned directly on `Genus`, plus one genuine causal chain
/// (`Genus` -> `LightningThunderAssociated` -> `LightningSeen`/
/// `ThunderHeard`) and three cross-question "not applicable" dependencies
/// dictated by `BayesianNetworkDesign.md` (`SpreadAsVeil` gates `Granular`
/// and `ElementSize`; `UniformBase` gates `Ragged`).
struct GenusNetworkContentTests {

    private static let resourcesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Clouds/Resources")

    /// Every askable question node id — excludes both "Genus" and the
    /// hidden "LightningThunderAssociated" node, which has no
    /// `QuestionDefinition` and is never asked directly.
    private static let questionNodeIDs = [
        "LightningSeen", "ThunderHeard", "OpticalThickness", "Shading",
        "SpreadAsVeil", "FlattenedBase", "VerticalDevelopment", "ThinFilaments",
        "Sheaves", "HookOrTuft", "Granular", "ElementSize", "SilkySheen",
        "Fibrous", "Undulated", "UniformBase", "Ragged", "DiffuseBase"
    ]

    /// Nodes whose applicability genuinely varies with evidence, so they
    /// carry a "NotApplicable" state (CLD-8). Most of this redesign's
    /// questions are always answerable (e.g. optical thickness, shading)
    /// and so deliberately don't have one.
    private static let notApplicableNodeIDs: Set<String> = [
        "LightningSeen", "ThunderHeard", "SpreadAsVeil", "FlattenedBase",
        "VerticalDevelopment", "ThinFilaments", "Sheaves", "HookOrTuft",
        "Granular", "ElementSize", "Ragged"
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

    private func mostLikelyGenus(_ network: BayesianNetwork, given evidence: [NodeID: StateID]) throws -> StateID {
        let posterior = try network.posterior(of: "Genus", given: evidence)
        return try #require(posterior.max(by: { $0.value < $1.value })?.key)
    }

    // MARK: - Structural validation

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

    @Test func onlyTheDesignatedNodesCarryANotApplicableState() throws {
        let file = try decodeNetworkFile()
        let nodesByID = Dictionary(uniqueKeysWithValues: file.nodes.map { ($0.id, $0) })

        for id in Self.questionNodeIDs {
            let node = try #require(nodesByID[id])
            let hasNotApplicable = node.states.contains(QuestionDefinition.notApplicableStateID)
            #expect(hasNotApplicable == Self.notApplicableNodeIDs.contains(id))
        }
    }

    /// "LightningThunderAssociated" has no matching question file (it's a
    /// hidden node, per the design's `Genus -> F-LIG -> {Q-LIG, Q-THUN}`
    /// chain), so it must never show up as something the UI would try to ask.
    @Test func hiddenAssociationNodeHasNoQuestionFile() throws {
        let url = Self.resourcesURL.appendingPathComponent("Questions/LightningThunderAssociated.json")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - The F-LIG causal chain (the ticket's core correctness fix)

    /// The design doc originally proposed `{Q-LIG, Q-THUN} -> F-LIG <- Genus`,
    /// which would make F-LIG an unobserved collider: since it's never
    /// entered as evidence, `Genus` and the two questions would be
    /// d-separated and answering them would move `Genus`'s posterior *not
    /// at all*. The user redirected this to a proper causal chain,
    /// `Genus -> F-LIG -> {LightningSeen, ThunderHeard}`, specifically so
    /// evidence flows without needing F-LIG to be directly observed. This
    /// test is the regression guard for that fix actually working.
    @Test func lightningSeenFavorsCumulonimbusThroughTheHiddenAssociationNode() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let prior = try network.posterior(of: "Genus")["Cb"] ?? 0
        let posterior = try network.posterior(of: "Genus", given: ["LightningSeen": "Yes"])["Cb"] ?? 0

        #expect(posterior > prior)
        #expect(try mostLikelyGenus(network, given: ["LightningSeen": "Yes"]) == "Cb")
    }

    /// Thunder can come from an unrelated storm cell (the design doc's own
    /// concern), so on its own it should move the posterior toward Cb by
    /// less than a direct sighting of lightning tied to the cloud does.
    @Test func thunderHeardAloneIsAWeakerCumulonimbusSignalThanLightningSeen() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let afterThunder = try network.posterior(of: "Genus", given: ["ThunderHeard": "Yes"])["Cb"] ?? 0
        let afterLightning = try network.posterior(of: "Genus", given: ["LightningSeen": "Yes"])["Cb"] ?? 0

        #expect(afterThunder < afterLightning)
    }

    @Test func noLightningOrThunderMakesCumulonimbusLessLikely() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let prior = try network.posterior(of: "Genus")["Cb"] ?? 0
        let evidence: [NodeID: StateID] = ["LightningSeen": "No", "ThunderHeard": "No"]
        let posterior = try network.posterior(of: "Genus", given: evidence)["Cb"] ?? 0

        #expect(posterior < prior)
    }

    // MARK: - Cross-question NotApplicable relations

    /// Q-VEIL -> Q-GRAN: a veil cloud has no distinct elements to judge as
    /// granular or not.
    @Test func granularBecomesNotApplicableOnceSpreadAsVeilIsYes() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let whenVeiled = try network.posterior(of: "Granular", given: ["SpreadAsVeil": "Yes"])[
            QuestionDefinition.notApplicableStateID
        ] ?? 0
        let whenNotVeiled = try network.posterior(of: "Granular", given: ["SpreadAsVeil": "No"])[
            QuestionDefinition.notApplicableStateID
        ] ?? 0

        #expect(whenVeiled > 0.8)
        #expect(whenNotVeiled < 0.2)
    }

    /// Q-VEIL -> Q-SIZE and Q-GRAN -> Q-SIZE: not applicable once veiled;
    /// clearly applicable once non-veiled and confirmed granular; only
    /// partially applicable ("can be applicable") when non-veiled but not
    /// granular.
    @Test func elementSizeApplicabilityFollowsVeilAndGranularEvidence() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let notApplicable = QuestionDefinition.notApplicableStateID

        let veiled = try network.posterior(
            of: "ElementSize", given: ["SpreadAsVeil": "Yes"]
        )[notApplicable] ?? 0
        let granular = try network.posterior(
            of: "ElementSize", given: ["SpreadAsVeil": "No", "Granular": "Yes"]
        )[notApplicable] ?? 0
        let notGranular = try network.posterior(
            of: "ElementSize", given: ["SpreadAsVeil": "No", "Granular": "No"]
        )[notApplicable] ?? 0

        #expect(veiled > granular)
        #expect(notGranular > granular)
    }

    /// Q-UNBA -> Q-RAGG: a clean uniform base can't also be ragged/torn.
    @Test func raggedBecomesNotApplicableOnceUniformBaseIsYes() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let whenUniform = try network.posterior(of: "Ragged", given: ["UniformBase": "Yes"])[
            QuestionDefinition.notApplicableStateID
        ] ?? 0
        let whenNotUniform = try network.posterior(of: "Ragged", given: ["UniformBase": "No"])[
            QuestionDefinition.notApplicableStateID
        ] ?? 0

        #expect(whenUniform > 0.8)
        #expect(whenNotUniform < 0.2)
    }

    // MARK: - Directional genus classification

    // Each of the following checks a feature combination that the
    // Tabular Guide (cloudatlas.wmo.int/en/tabular-guide-genus.html)
    // marks Essential or unambiguously distinguishing for one genus,
    // rather than replaying a fixed decision-tree path (there is no
    // single path through this design's naive-Bayes-style structure).

    @Test func thinVeilFavorsCirrostratus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = ["SpreadAsVeil": "Yes", "OpticalThickness": "Thin"]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cs")
    }

    @Test func smallGranularElementsFavorCirrocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "SpreadAsVeil": "No", "Granular": "Yes", "ElementSize": "LessThanOneDegree"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cc")
    }

    @Test func largeElementsFavorStratocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "SpreadAsVeil": "No", "Granular": "Yes", "ElementSize": "MoreThanFiveDegrees"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Sc")
    }

    @Test func thinFilamentsWithHookFavorCirrus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "ThinFilaments": "Yes", "HookOrTuft": "Yes", "SilkySheen": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Ci")
    }

    @Test func flattenedDetachedBaseFavorsCumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "FlattenedBase": "Yes", "VerticalDevelopment": "YesDetached", "LightningSeen": "No"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cu")
    }
}
