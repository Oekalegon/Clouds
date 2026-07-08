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
    let posterior: [StateID: Double]
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
                            VStack(spacing: 2) {
                                Text(answer.label)
                                if let description = answer.description {
                                    Text(description)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                            }
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
        .overlay(alignment: .topTrailing) {
            DebugPosteriorView(posterior: posterior)
                .padding()
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
            id: "LightningSeen",
            text: "Is lightning seen to be associated with this cloud?",
            description: "Only count lightning you can see coming from this specific cloud, not a flash elsewhere in the sky.",
            image: nil,
            answers: [
                QuestionAnswer(id: "Yes", label: "Yes", description: "A flash you can see coming from this cloud"),
                QuestionAnswer(id: "No", label: "No")
            ]
        ),
        selectedAnswer: nil,
        posterior: ["Cb": 0.62, "Cu": 0.21, "Sc": 0.09, "Ac": 0.05, "St": 0.02, "Ci": 0.01],
        onSelect: { _ in }
    )
}
