//
//  QuestionDefinition.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// The JSON representation of a single question: its text, optional
/// description and image, and its possible answers. The `id` matches the
/// corresponding node's id in a `BayesianNetworkFile`; each answer's `id`
/// matches one of that node's states.
struct QuestionDefinition: Decodable {
    let id: NodeID
    let text: String
    let description: String?
    let image: String?
    let answers: [QuestionAnswer]
}

struct QuestionAnswer: Decodable, Hashable {
    let id: StateID
    let label: String
}

extension QuestionDefinition {
    /// Checks that this question's answer ids are exactly the given node's
    /// states — no missing answers, no stray ones. Does not check that a
    /// network node with this id actually exists; assembling a network
    /// with its questions is a future ticket's concern.
    func validate(against states: [StateID]) throws {
        let expected = Set(states)
        let actual = Set(answers.map(\.id))
        guard actual == expected else {
            throw SchemaError.answerStateMismatch(question: id, expectedStates: expected, actualStates: actual)
        }
    }
}
