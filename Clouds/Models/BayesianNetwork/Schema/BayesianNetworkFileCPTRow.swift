//
//  BayesianNetworkFileCPTRow.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

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
