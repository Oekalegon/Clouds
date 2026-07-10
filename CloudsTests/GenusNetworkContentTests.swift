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
/// `ThunderHeard`) and cross-question "not applicable" dependencies
/// (`HasDistinctElements` gates `Granular` and `ElementSize`; `UniformBase`
/// gates `Ragged`).
///
/// `HasDistinctElements` and `Precipitation` were added, and every binary
/// Yes/No question recalibrated, after a real-world test pass
/// (`TestCases.md`, tracked outside the repo) found: (1) a calibration bug
/// where "Possible" and "Usual" labels both produced a ~80-95% Yes
/// probability, collapsing the Tabular Guide's E/U/P distinction and
/// making a "No" answer look like strong evidence for *any* completely
/// unlabelled genus; and (2) `Granular`/`ElementSize` being asked (and
/// answerable) for clouds that aren't actually elemental at all — a single
/// detached Cumulus, or a ragged Stratus sheet — because the only gate
/// was "not a veil", which doesn't rule out non-veil, non-elemental clouds.
struct GenusNetworkContentTests {

    /// Every askable question node id — excludes both "Genus" and the
    /// hidden "LightningThunderAssociated" node, which has no
    /// `QuestionDefinition` and is never asked directly. Includes the
    /// Supplementary Features/Accessory Clouds added after genus
    /// identification (CLD-9), since they're real network nodes with the
    /// same structural requirements (answer-button budget, NotApplicable
    /// state consistency) as any other question.
    private static let questionNodeIDs = [
        "LightningSeen", "ThunderHeard", "OpticalThickness", "Shading",
        "SpreadAsVeil", "FlattenedBase", "VerticalDevelopment", "ThinFilaments",
        "Sheaves", "HookOrTuft", "HasDistinctElements", "Granular", "ElementSize", "SilkySheen",
        "Fibrous", "Undulated", "UniformBase", "Ragged", "DiffuseBase", "Precipitation",
        "Incus", "Mamma", "Virga", "Arcus", "Tuba", "Asperitas", "Murus", "Cauda", "Cavum", "Fluctus",
        "Pileus", "Velum", "Pannus", "Flumen"
    ]

    /// Nodes whose applicability genuinely varies with evidence, so they
    /// carry a "NotApplicable" state (CLD-8). Most of this redesign's
    /// questions are always answerable (e.g. optical thickness, shading)
    /// and so deliberately don't have one.
    private static let notApplicableNodeIDs: Set<String> = [
        "LightningSeen", "ThunderHeard", "SpreadAsVeil", "FlattenedBase",
        "VerticalDevelopment", "ThinFilaments", "Sheaves", "HookOrTuft",
        "Granular", "ElementSize", "Ragged", "Incus"
    ]

    /// Every question must fit an answer-buttons UI without scrolling.
    private static let maxAnswersPerQuestion = 4

    private func decodeNetworkFile() throws -> BayesianNetworkFile {
        try RealContentLoading.decodeNetworkFile()
    }

    private func decodeQuestion(_ id: String) throws -> QuestionDefinition {
        try #require(RealContentLoading.decodeQuestion(id))
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
        #expect(RealContentLoading.decodeQuestion("LightningThunderAssociated") == nil)
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

    /// "HasDistinctElements" gates "Granular": a cloud that isn't made of
    /// distinct elements at all (a veil, or a single convective mass) has
    /// nothing to judge as granular or not (CLD-9 TestCases.md review).
    @Test func granularBecomesNotApplicableWhenThereAreNoDistinctElements() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let withoutElements = try network.posterior(of: "Granular", given: ["HasDistinctElements": "No"])[
            QuestionDefinition.notApplicableStateID
        ] ?? 0
        let withElements = try network.posterior(of: "Granular", given: ["HasDistinctElements": "Yes"])[
            QuestionDefinition.notApplicableStateID
        ] ?? 0

        #expect(withoutElements > 0.8)
        #expect(withElements < 0.2)
    }

    /// "HasDistinctElements" and "Granular" both gate "ElementSize": not
    /// applicable at all when the cloud isn't elemental; clearly applicable
    /// once it is and confirmed granular; only partially applicable ("can
    /// be applicable") when elemental but not granular.
    @Test func elementSizeApplicabilityFollowsHasDistinctElementsAndGranularEvidence() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let notApplicable = QuestionDefinition.notApplicableStateID

        let noElements = try network.posterior(
            of: "ElementSize", given: ["HasDistinctElements": "No"]
        )[notApplicable] ?? 0
        let granular = try network.posterior(
            of: "ElementSize", given: ["HasDistinctElements": "Yes", "Granular": "Yes"]
        )[notApplicable] ?? 0
        let notGranular = try network.posterior(
            of: "ElementSize", given: ["HasDistinctElements": "Yes", "Granular": "No"]
        )[notApplicable] ?? 0

        #expect(noElements > granular)
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

    // MARK: - Supplementary Features / Accessory Clouds (CLD-9)

    /// Incus (Q-INCU) is the one Supplementary Feature with real
    /// not-applicable gating: an anvil needs vertical development to
    /// exist at all, and is only worth asking about once lightning/
    /// thunder has already made Cb plausible — per
    /// `BayesianNetworkDesign.md`'s own not-applicable relations for it.
    @Test func incusRequiresVerticalDevelopmentAndIsMoreApplicableWithLightningOrThunder() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let notApplicable = QuestionDefinition.notApplicableStateID

        let noVerticalDevelopment = try network.posterior(
            of: "Incus", given: ["VerticalDevelopment": "No"]
        )[notApplicable] ?? 0
        let withLightning = try network.posterior(
            of: "Incus", given: ["VerticalDevelopment": "YesDetached", "LightningSeen": "Yes"]
        )[notApplicable] ?? 0
        let withoutLightningOrThunder = try network.posterior(
            of: "Incus", given: ["VerticalDevelopment": "YesDetached", "LightningSeen": "No", "ThunderHeard": "No"]
        )[notApplicable] ?? 0

        #expect(noVerticalDevelopment > withoutLightningOrThunder)
        #expect(withoutLightningOrThunder > withLightning)
    }

    /// Every Supplementary Feature/Accessory Cloud is Genus-conditioned
    /// only (a single question per feature doesn't need Lightning/
    /// Thunder's hidden-node treatment) — except Incus, gated as above.
    @Test func everySupplementaryFeatureAndAccessoryCloudIsGenusConditionedExceptIncus() throws {
        let catalog = try RealContentLoading.loadCatalog()
        for id in catalog.supplementaryFeatureNodeIDs + catalog.accessoryCloudNodeIDs where id != "Incus" {
            #expect(catalog.network.nodes[id]?.parentIDs == ["Genus"], "\(id) should depend only on Genus")
        }
        #expect(catalog.network.nodes["Incus"]?.parentIDs.contains("Genus") == true)
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
            "HasDistinctElements": "Yes", "Granular": "Yes", "ElementSize": "LessThanOneDegree"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cc")
    }

    @Test func largeElementsFavorStratocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "HasDistinctElements": "Yes", "Granular": "Yes", "ElementSize": "MoreThanFiveDegrees"
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

    /// A single detached Cumulus isn't "made of elements" (that's Cc/Ac/Sc's
    /// defining structure per the WMO Tabular Guide), so answering "No" to
    /// "HasDistinctElements" should rule ElementSize/Granular out rather
    /// than leaving Cumulus to be dragged toward Stratocumulus by a forced
    /// element-size answer (TestCases.md case 5).
    @Test func noDistinctElementsWithFlattenedDetachedBaseFavorsCumulusOverStratocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "HasDistinctElements": "No", "FlattenedBase": "Yes", "VerticalDevelopment": "YesDetached"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cu")
    }

    /// Continuous rain/snow reaching the ground is Nimbostratus's actual
    /// defining feature per the WMO Tabular Guide — observing its absence
    /// should weigh heavily against Ns even when other features (a diffuse
    /// base, a uniform veil) are shared with Altostratus/Stratus
    /// (TestCases.md case 2).
    @Test func noPrecipitationWeighsAgainstNimbostratus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let prior = try network.posterior(of: "Genus")["Ns"] ?? 0
        let posterior = try network.posterior(of: "Genus", given: ["Precipitation": "No"])["Ns"] ?? 0

        #expect(posterior < prior)
    }

    // MARK: - Calibration regression (the ticket's E/U/P collapse bug)

    /// Regression guard for a bug where every labelled genus (Essential,
    /// Usual, *or* merely Possible) got an ~80-95% Yes probability, and
    /// only a completely unlabelled genus got a low one — collapsing the
    /// Tabular Guide's Essential/Usual/Possible distinction into "labelled
    /// vs not", and making completely unrelated, unlabelled genera look
    /// like *better* fits for a "No" answer than genera the guide
    /// documents as occasionally showing the feature (TestCases.md case 2:
    /// Nimbostratus, wholly unlabelled for "Undulated", beat Altostratus/
    /// Stratus, both genuinely "Possible" there, on a "No" answer).
    @Test func possibleLabelYesProbabilityIsClearlyBetweenUnlabelledAndUsual() throws {
        let network = try decodeNetworkFile().makeNetwork()

        // "Undulated": Cs is "Possible", Ns carries no label at all.
        let possibleYes = try network.posterior(of: "Undulated", given: ["Genus": "Cs"])["Yes"] ?? 0
        let unlabelledYes = try network.posterior(of: "Undulated", given: ["Genus": "Ns"])["Yes"] ?? 0
        // "Undulated": Cc is "Usual".
        let usualYes = try network.posterior(of: "Undulated", given: ["Genus": "Cc"])["Yes"] ?? 0

        #expect(unlabelledYes < possibleYes)
        #expect(possibleYes < usualYes)
        #expect(possibleYes < 0.4)
    }

    // MARK: - Real-world test cases (TestCases.md, captured 2026-07-08)

    /// Each of these mirrors one full Q&A walk a real tester actually
    /// answered for a real cloud, captured via `IdentificationSession`'s
    /// TESTSET debug logging. Case 1 (a Stratus fractus) is wrapped in
    /// `withKnownIssue`: fractus is a *species*-level distinction (a torn,
    /// ragged Stratus variant) that this genus-only network can't
    /// separate from a similarly "detached, non-uniform-based" Cumulus —
    /// modelling it needs the Species content the design doc explicitly
    /// defers to a later ticket, not a genus-level CPT tweak.
    @Test func testCase1StratusFractusIsAKnownGenusVsSpeciesAmbiguity() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "Shading": "PartlyShaded", "UniformBase": "No", "Undulated": "No", "DiffuseBase": "No",
            "ThinFilaments": "No", "Ragged": "Yes", "FlattenedBase": "No",
            "VerticalDevelopment": "YesDetached", "OpticalThickness": "Opaque", "LightningSeen": "No",
            "Fibrous": "No", "SilkySheen": "No", "ThunderHeard": "No", "SpreadAsVeil": "No",
            "Sheaves": "No", "HookOrTuft": "No", "HasDistinctElements": "No", "Precipitation": "No"
        ]

        let genus = try mostLikelyGenus(network, given: evidence)
        withKnownIssue("Fractus is a Stratus species, not yet modelled by this genus-only network") {
            #expect(genus == "St")
        }
    }

    @Test func testCase3SmallGranularElementsFavorCirrocumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "Shading": "NoShading", "Granular": "Yes", "ElementSize": "LessThanOneDegree",
            "HasDistinctElements": "Yes"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cc")
    }

    @Test func testCase4ThinFilamentsWithHookFavorCirrus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "Shading": "NoShading", "Granular": "No", "ThinFilaments": "Yes", "Sheaves": "No",
            "UniformBase": "No", "HookOrTuft": "Yes", "Undulated": "No", "HasDistinctElements": "No"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Ci")
    }

    @Test func testCase5FlattenedDetachedNonElementalCloudFavorsCumulus() throws {
        let network = try decodeNetworkFile().makeNetwork()
        let evidence: [NodeID: StateID] = [
            "Shading": "PartlyShaded", "UniformBase": "No", "Undulated": "No", "DiffuseBase": "No",
            "HookOrTuft": "No", "Ragged": "No", "VerticalDevelopment": "YesDetached",
            "FlattenedBase": "Yes", "OpticalThickness": "Opaque", "LightningSeen": "No",
            "Fibrous": "No", "SilkySheen": "No", "ThunderHeard": "No", "SpreadAsVeil": "No",
            "ThinFilaments": "No", "Sheaves": "No", "HasDistinctElements": "No", "Precipitation": "No"
        ]
        #expect(try mostLikelyGenus(network, given: evidence) == "Cu")
    }
}
