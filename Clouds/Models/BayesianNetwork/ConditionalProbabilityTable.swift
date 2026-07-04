//
//  ConditionalProbabilityTable.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// The conditional probability table (CPT) for a single node: a
/// distribution over that node's states for every combination of its
/// parents' states. Root nodes (no parents) have a single entry keyed by
/// the empty `Assignment`.
struct ConditionalProbabilityTable: Hashable {
    private let rows: [Assignment: [StateID: Double]]

    init(_ rows: [Assignment: [StateID: Double]]) {
        self.rows = rows
    }

    var parentAssignments: [Assignment] {
        Array(rows.keys)
    }

    func distribution(givenParents parentAssignment: Assignment) -> [StateID: Double]? {
        rows[parentAssignment]
    }

    func probability(of state: StateID, givenParents parentAssignment: Assignment) -> Double {
        rows[parentAssignment]?[state] ?? 0
    }
}
