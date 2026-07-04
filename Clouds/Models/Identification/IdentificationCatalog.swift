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

    /// Every question node id, in the order declared in the network file,
    /// excluding the root "Genus" classification node.
    let questionNodeIDs: [NodeID]

    private static let genusNodeID: NodeID = "Genus"

    /// Pure assembly: builds the network and cross-validates every
    /// question against its node's states. No I/O, fully unit-testable.
    init(networkFile: BayesianNetworkFile, questionFiles: [QuestionDefinition]) throws {
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
        self.questionNodeIDs = networkFile.nodes.map(\.id).filter { $0 != Self.genusNodeID }
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
        let questionFiles = try questionIDs.map { id -> QuestionDefinition in
            guard let url = Self.resourceURL(named: id, extension: "json", subdirectory: "Questions", in: bundle) else {
                throw IdentificationCatalogError.missingResource("\(id).json")
            }
            return try decoder.decode(QuestionDefinition.self, from: Data(contentsOf: url))
        }

        try self.init(networkFile: networkFile, questionFiles: questionFiles)
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
