//
//  SchemaError.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// Errors from decoding/validating the JSON schema for network and question
/// files. Distinct from `BayesianNetworkError`, which covers the engine's
/// own graph/probability invariants.
enum SchemaError: Error, Equatable {
    /// Two CPT rows for the same node specify the same parent assignment.
    case duplicateCPTRow(node: NodeID, given: Assignment)

    /// A question's answer ids don't exactly match its node's states.
    case answerStateMismatch(question: NodeID, expectedStates: Set<StateID>, actualStates: Set<StateID>)

    /// A question lists the same answer id more than once.
    case duplicateAnswer(question: NodeID)
}
