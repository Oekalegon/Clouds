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

struct BayesianNetworkFileNode: Decodable {
    let id: NodeID
    let states: [StateID]
    let parents: [NodeID]
    let cpt: [BayesianNetworkFileCPTRow]

    private enum CodingKeys: String, CodingKey {
        case id, states, parents, cpt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        states = try container.decode([StateID].self, forKey: .states)
        parents = try container.decodeIfPresent([NodeID].self, forKey: .parents) ?? []
        cpt = try container.decode([BayesianNetworkFileCPTRow].self, forKey: .cpt)
    }
}

/// A single row of a node's CPT: the distribution over that node's states
/// given one combination of its parents' states. `given` is omitted (or
/// empty) for root nodes.
struct BayesianNetworkFileCPTRow: Decodable {
    let given: [NodeID: StateID]
    let distribution: [StateID: Double]

    private enum CodingKeys: String, CodingKey {
        case given, distribution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        given = try container.decodeIfPresent([NodeID: StateID].self, forKey: .given) ?? [:]
        distribution = try container.decode([StateID: Double].self, forKey: .distribution)
    }
}

extension BayesianNetworkFileNode {
    func makeNode() -> BayesianNetworkNode {
        BayesianNetworkNode(id: id, states: states, parentIDs: parents)
    }
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
