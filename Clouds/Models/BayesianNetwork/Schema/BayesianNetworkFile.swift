//
//  BayesianNetworkFile.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// The JSON representation of a `BayesianNetwork`: a list of nodes, each
/// with its states, parents, and conditional probability table.
struct BayesianNetworkFile: Decodable {
    let nodes: [BayesianNetworkFileNode]
}

extension BayesianNetworkFile {
    /// Builds a validated `BayesianNetwork` from the decoded file. All
    /// structural/probabilistic validation (duplicate node ids, unknown
    /// parents, cycles, incomplete CPTs, probabilities not summing to 1) is
    /// performed by `BayesianNetwork.init` itself, not duplicated here.
    func makeNetwork() throws -> BayesianNetwork {
        let nodes = self.nodes.map { $0.makeNode() }

        var cpts: [NodeID: ConditionalProbabilityTable] = [:]
        for fileNode in self.nodes {
            var rows: [Assignment: [StateID: Double]] = [:]
            for row in fileNode.cpt {
                let assignment = Assignment(row.given)
                guard rows[assignment] == nil else {
                    throw SchemaError.duplicateCPTRow(node: fileNode.id, given: assignment)
                }
                rows[assignment] = row.distribution
            }
            cpts[fileNode.id] = ConditionalProbabilityTable(rows)
        }

        return try BayesianNetwork(nodes: nodes, cpts: cpts)
    }
}
