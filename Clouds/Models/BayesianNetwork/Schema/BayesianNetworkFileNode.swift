//
//  BayesianNetworkFileNode.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// The JSON representation of a single node within a `BayesianNetworkFile`.
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

extension BayesianNetworkFileNode {
    func makeNode() -> BayesianNetworkNode {
        BayesianNetworkNode(id: id, states: states, parentIDs: parents)
    }
}
