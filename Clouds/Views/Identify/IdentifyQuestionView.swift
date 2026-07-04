//
//  IdentifyQuestionView.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import SwiftUI
import UIKit

struct IdentifyQuestionView: View {
    let question: QuestionDefinition
    let selectedAnswer: StateID?
    let onSelect: (StateID) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            VStack(alignment: .leading, spacing: 12) {
                Text(question.text)
                    .font(.title2.bold())

                if let description = question.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(question.answers, id: \.id) { answer in
                        Button {
                            onSelect(answer.id)
                        } label: {
                            Text(answer.label)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(answer.id == selectedAnswer ? .accentColor : .secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
            .background(.thinMaterial)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let imageName = question.image, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [.blue.opacity(0.3), .gray.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

#Preview {
    IdentifyQuestionView(
        question: QuestionDefinition(
            id: "LightningOrThunder",
            text: "Is lightning seen or thunder heard?",
            description: "This is the clearest sign of a Cumulonimbus, even when the cloud's shape is hard to judge.",
            image: nil,
            answers: [
                QuestionAnswer(id: "Yes", label: "Yes"),
                QuestionAnswer(id: "No", label: "No"),
                QuestionAnswer(id: "Unsure", label: "Not sure")
            ]
        ),
        selectedAnswer: nil,
        onSelect: { _ in }
    )
}
