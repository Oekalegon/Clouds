//
//  IdentificationCatalog.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

enum IdentificationCatalogError: Error, Equatable {
    case missingResource(String)
}

/// The assembled Bayesian Network and its questions, ready for the Q&A
/// flow: the decoded/validated `BayesianNetwork` plus every question,
/// keyed by node id.
struct IdentificationCatalog: Sendable {
    let network: BayesianNetwork
    let questions: [NodeID: QuestionDefinition]

    /// Every askable question node id, in the order declared in the
    /// network file. A node is a question iff a matching `QuestionDefinition`
    /// was supplied (CLD-3's rule) — this excludes both the root "Genus"
    /// classification node and any hidden/derived nodes (e.g. CLD-9's
    /// "LightningThunderAssociated", never asked directly, only inferred
    /// from the questions that are its children). Includes supplementary
    /// features and accessory clouds too: they're valid genus evidence
    /// like any other question, so `bestNextQuestion` can pick them during
    /// genus identification if they're ever the most informative choice.
    let questionNodeIDs: [NodeID]

    /// The subset of `questionNodeIDs` that are WMO Supplementary Features
    /// (Incus, Mamma, ...) rather than genus-identification questions —
    /// see `QuestionCategories`. Asked in a follow-up pass once the genus
    /// itself is confidently known, so a session's final report can note
    /// which were actually observed.
    let supplementaryFeatureNodeIDs: [NodeID]

    /// The subset of `questionNodeIDs` that are WMO Accessory Clouds
    /// (Pileus, Velum, ...) — see `supplementaryFeatureNodeIDs`.
    let accessoryCloudNodeIDs: [NodeID]

    /// `questionNodeIDs` minus the two feature categories above — what
    /// `IdentificationSession`'s genus-identification phase actually
    /// selects from.
    var genusIdentificationNodeIDs: [NodeID] {
        let featureIDs = Set(supplementaryFeatureNodeIDs).union(accessoryCloudNodeIDs)
        return questionNodeIDs.filter { !featureIDs.contains($0) }
    }

    private static let genusNodeID: NodeID = "Genus"

    /// Pure assembly: builds the network and cross-validates every
    /// question against its node's states. No I/O, fully unit-testable.
    /// `supplementaryFeatureIDs`/`accessoryCloudIDs` default to empty so
    /// existing call sites that don't care about categorization (most
    /// tests) don't need to pass them.
    init(
        networkFile: BayesianNetworkFile,
        questionFiles: [QuestionDefinition],
        supplementaryFeatureIDs: Set<NodeID> = [],
        accessoryCloudIDs: Set<NodeID> = []
    ) throws {
        let network = try networkFile.makeNetwork()

        var questionsByID: [NodeID: QuestionDefinition] = [:]
        for question in questionFiles {
            guard let node = network.nodes[question.id] else {
                throw IdentificationCatalogError.missingResource(question.id)
            }
            try question.validate(against: node.states)
            questionsByID[question.id] = question
        }

        self.network = network
        self.questions = questionsByID
        self.questionNodeIDs = networkFile.nodes.map(\.id).filter { questionsByID[$0] != nil }
        self.supplementaryFeatureNodeIDs = self.questionNodeIDs.filter { supplementaryFeatureIDs.contains($0) }
        self.accessoryCloudNodeIDs = self.questionNodeIDs.filter { accessoryCloudIDs.contains($0) }
    }

    /// Loads the real content from the app bundle. Resources are looked up
    /// first in their source subdirectory, then flat at the bundle root,
    /// since it's not certain which layout xcodegen's build phase produces.
    init(bundle: Bundle = .main) throws {
        let decoder = JSONDecoder()

        guard let networkURL = Self.resourceURL(
            named: "genus-network", extension: "json", subdirectory: "BayesianNetwork", in: bundle
        ) else {
            throw IdentificationCatalogError.missingResource("genus-network.json")
        }
        let networkFile = try decoder.decode(BayesianNetworkFile.self, from: Data(contentsOf: networkURL))

        let questionIDs = networkFile.nodes.map(\.id).filter { $0 != Self.genusNodeID }
        let questionFiles = try questionIDs.compactMap { id -> QuestionDefinition? in
            guard let url = Self.resourceURL(named: id, extension: "json", subdirectory: "Questions", in: bundle) else {
                // No matching file means this is a hidden/derived node
                // (e.g. "LightningThunderAssociated"), not a missing
                // resource — it's never asked directly.
                return nil
            }
            return try decoder.decode(QuestionDefinition.self, from: Data(contentsOf: url))
        }

        guard let categoriesURL = Self.resourceURL(
            named: "QuestionCategories", extension: "json", subdirectory: "", in: bundle
        ) else {
            throw IdentificationCatalogError.missingResource("QuestionCategories.json")
        }
        let categories = try decoder.decode(QuestionCategories.self, from: Data(contentsOf: categoriesURL))

        try self.init(
            networkFile: networkFile,
            questionFiles: questionFiles,
            supplementaryFeatureIDs: Set(categories.supplementaryFeatures),
            accessoryCloudIDs: Set(categories.accessoryClouds)
        )
    }

    private static func resourceURL(named name: String, extension ext: String, subdirectory: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: ext)
    }

    static let shared: IdentificationCatalog = {
        do {
            return try IdentificationCatalog(bundle: .main)
        } catch {
            fatalError("Could not load identification catalog: \(error)")
        }
    }()
}
