//
//  QuestionDefinitionTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

struct QuestionDefinitionTests {

    private func decodeQuestion(_ json: String) throws -> QuestionDefinition {
        try JSONDecoder().decode(QuestionDefinition.self, from: Data(json.utf8))
    }

    @Test func decodingQuestionDefinitionParsesAllFields() throws {
        let json = """
        {
          "id": "Cloudy",
          "text": "Is the sky mostly overcast?",
          "description": "Look at the sky as a whole, not just near the cloud you're identifying.",
          "image": "question-cloudy-sky",
          "answers": [
            { "id": "T", "label": "Yes, mostly overcast" },
            { "id": "F", "label": "No, mostly clear" }
          ]
        }
        """
        let question = try decodeQuestion(json)

        #expect(question.id == "Cloudy")
        #expect(question.text == "Is the sky mostly overcast?")
        #expect(question.description == "Look at the sky as a whole, not just near the cloud you're identifying.")
        #expect(question.image == "question-cloudy-sky")
        #expect(question.answers == [
            QuestionAnswer(id: "T", label: "Yes, mostly overcast"),
            QuestionAnswer(id: "F", label: "No, mostly clear")
        ])
    }

    @Test func decodingQuestionDefinitionAllowsOmittedDescriptionAndImage() throws {
        let json = """
        {
          "id": "Cloudy",
          "text": "Is the sky mostly overcast?",
          "answers": [
            { "id": "T", "label": "Yes" },
            { "id": "F", "label": "No" }
          ]
        }
        """
        let question = try decodeQuestion(json)

        #expect(question.description == nil)
        #expect(question.image == nil)
    }

    @Test func validateAgainstMatchingStatesSucceeds() throws {
        let question = QuestionDefinition(
            id: "Cloudy",
            text: "Is the sky mostly overcast?",
            description: nil,
            image: nil,
            answers: [
                QuestionAnswer(id: "T", label: "Yes"),
                QuestionAnswer(id: "F", label: "No")
            ]
        )

        try question.validate(against: ["T", "F"])
    }

    @Test func validateAgainstStatesExcludesNotApplicableFromRequiredAnswers() throws {
        let question = QuestionDefinition(
            id: "Cloudy",
            text: "Is the sky mostly overcast?",
            description: nil,
            image: nil,
            answers: [
                QuestionAnswer(id: "T", label: "Yes"),
                QuestionAnswer(id: "F", label: "No")
            ]
        )

        // "NotApplicable" is a real node state (CLD-8) but never a
        // selectable answer, so it must not be required here.
        try question.validate(against: ["T", "F", QuestionDefinition.notApplicableStateID])
    }

    @Test func validateAgainstMismatchedStatesThrows() throws {
        let question = QuestionDefinition(
            id: "Cloudy",
            text: "Is the sky mostly overcast?",
            description: nil,
            image: nil,
            answers: [
                QuestionAnswer(id: "T", label: "Yes"),
                QuestionAnswer(id: "F", label: "No"),
                QuestionAnswer(id: "Maybe", label: "Unsure")
            ]
        )

        #expect(throws: SchemaError.answerStateMismatch(
            question: "Cloudy",
            expectedStates: ["T", "F"],
            actualStates: ["T", "F", "Maybe"]
        )) {
            try question.validate(against: ["T", "F"])
        }
    }

    @Test func validateAgainstDuplicateAnswerIDThrows() throws {
        let question = QuestionDefinition(
            id: "Cloudy",
            text: "Is the sky mostly overcast?",
            description: nil,
            image: nil,
            answers: [
                QuestionAnswer(id: "T", label: "Yes, mostly overcast"),
                QuestionAnswer(id: "F", label: "No, mostly clear"),
                QuestionAnswer(id: "T", label: "Yes, definitely overcast")
            ]
        )

        #expect(throws: SchemaError.duplicateAnswer(question: "Cloudy")) {
            try question.validate(against: ["T", "F"])
        }
    }
}
