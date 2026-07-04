//
//  BayesianNetworkTypes.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

typealias NodeID = String
typealias StateID = String

/// A partial or full assignment of states to nodes, e.g. evidence or a
/// combination of parent states. Wrapped so it can be used as a
/// dictionary key, since `Dictionary` itself isn't `Hashable`.
struct Assignment: Hashable {
    let values: [NodeID: StateID]

    init(_ values: [NodeID: StateID] = [:]) {
        self.values = values
    }

    subscript(node: NodeID) -> StateID? {
        values[node]
    }

    func merging(_ other: Assignment) -> Assignment {
        Assignment(values.merging(other.values) { _, new in new })
    }

    func restricted(to nodes: some Sequence<NodeID>) -> Assignment {
        var result: [NodeID: StateID] = [:]
        for node in nodes {
            if let state = values[node] {
                result[node] = state
            }
        }
        return Assignment(result)
    }
}
