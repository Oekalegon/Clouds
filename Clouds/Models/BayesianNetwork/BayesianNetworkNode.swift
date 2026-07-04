//
//  BayesianNetworkNode.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// A single node in a `BayesianNetwork`. A node may represent either a
/// classification (e.g. cloud genus) or a question — the engine makes no
/// distinction; that meaning is assigned by callers.
struct BayesianNetworkNode: Hashable {
    let id: NodeID
    let states: [StateID]
    let parentIDs: [NodeID]

    init(id: NodeID, states: [StateID], parentIDs: [NodeID] = []) {
        self.id = id
        self.states = states
        self.parentIDs = parentIDs
    }
}
