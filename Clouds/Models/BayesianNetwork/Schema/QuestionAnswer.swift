//
//  QuestionAnswer.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// A single possible answer to a `QuestionDefinition`. Its `id` matches
/// one of the corresponding node's states in a `BayesianNetworkFile`.
struct QuestionAnswer: Decodable, Hashable {
    let id: StateID
    let label: String
    let description: String?

    init(id: StateID, label: String, description: String? = nil) {
        self.id = id
        self.label = label
        self.description = description
    }
}
