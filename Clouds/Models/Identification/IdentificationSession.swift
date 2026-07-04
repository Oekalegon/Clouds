//
//  IdentificationSession.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation
import os

/// Drives the Q&A flow: which question to show next (by expected
/// information gain over "Genus"), the running posterior, and browser-
/// history-style navigation so past answers can be revisited and changed.
@MainActor
@Observable
final class IdentificationSession {
    struct AnsweredQuestion: Equatable {
        let questionID: NodeID
        var answer: StateID
    }

    private static let targetNodeID: NodeID = "Genus"
    private static let logger = Logger(subsystem: "org.oekalegon.Clouds", category: "Identification")

    private let catalog: IdentificationCatalog
    private let confidenceThreshold: Double

    private(set) var history: [AnsweredQuestion] = []
    private(set) var currentIndex = 0

    private(set) var currentQuestionID: NodeID?
    private(set) var posterior: [StateID: Double] = [:]
    private(set) var isFinished = false
    private(set) var isComputingNextQuestion = false

    init(catalog: IdentificationCatalog = .shared, confidenceThreshold: Double = 0.9) {
        self.catalog = catalog
        self.confidenceThreshold = confidenceThreshold
    }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < history.count }

    /// The most likely genus given the posterior so far. Ties are broken
    /// deterministically by the network's declared state order (`max(by:)`
    /// keeps the first maximal element), so an uninformative (flat)
    /// posterior still yields a stable result.
    var mostLikelyGenus: StateID? {
        guard let states = catalog.network.nodes[Self.targetNodeID]?.states, !states.isEmpty else {
            return nil
        }
        return states.max { (posterior[$0] ?? 0) < (posterior[$1] ?? 0) }
    }

    func currentQuestion() -> QuestionDefinition? {
        currentQuestionID.flatMap { catalog.questions[$0] }
    }

    /// The answer already recorded for the question currently being
    /// reviewed, if any (nil when at the live edge, about to ask a new one).
    var currentAnswer: StateID? {
        currentIndex < history.count ? history[currentIndex].answer : nil
    }

    func start() async {
        await refresh()
    }

    func selectAnswer(_ state: StateID) async {
        guard let questionID = currentQuestionID else { return }

        if currentIndex < history.count {
            if history[currentIndex].answer != state {
                history[currentIndex].answer = state
                history.removeSubrange((currentIndex + 1)...)
            }
        } else {
            history.append(AnsweredQuestion(questionID: questionID, answer: state))
        }
        currentIndex += 1
        await refresh()
    }

    func goBack() async {
        guard canGoBack else { return }
        currentIndex -= 1
        await refresh()
    }

    func goForward() async {
        guard canGoForward else { return }
        currentIndex += 1
        await refresh()
    }

    private var currentEvidence: [NodeID: StateID] {
        Dictionary(uniqueKeysWithValues: history.prefix(currentIndex).map { ($0.questionID, $0.answer) })
    }

    private func refresh() async {
        let evidence = currentEvidence
        let network = catalog.network

        posterior = (try? network.posterior(of: Self.targetNodeID, given: evidence)) ?? [:]
        logPosterior(after: history.prefix(currentIndex).last)

        if currentIndex < history.count {
            currentQuestionID = history[currentIndex].questionID
            isFinished = false
            isComputingNextQuestion = false
            return
        }

        let remainingCandidates = catalog.questionNodeIDs.filter { evidence[$0] == nil }
        let isConfident = (posterior.values.max() ?? 0) >= confidenceThreshold

        if isConfident || remainingCandidates.isEmpty {
            isFinished = true
            currentQuestionID = nil
            isComputingNextQuestion = false
            return
        }

        isFinished = false
        isComputingNextQuestion = true
        let targets = [Self.targetNodeID]
        let next = await Task.detached {
            try? network.bestNextQuestion(among: remainingCandidates, forTargets: targets, given: evidence)
        }.value
        currentQuestionID = next
        isComputingNextQuestion = false
    }

    /// Logs the current genus posterior, sorted most-to-least likely, with
    /// the question/answer that produced it (nil evidence for the very
    /// first computation, before any question has been answered).
    private func logPosterior(after lastAnswered: AnsweredQuestion?) {
        let ranked = posterior
            .sorted { $0.value > $1.value }
            .map { state, probability in
                let name = CloudGenus(rawValue: state)?.displayName ?? state
                return "\(name): \(String(format: "%.1f", probability * 100))%"
            }
            .joined(separator: ", ")

        if let lastAnswered {
            Self.logger.info("Posterior after \(lastAnswered.questionID, privacy: .public)='\(lastAnswered.answer, privacy: .public)': \(ranked, privacy: .public)")
        } else {
            Self.logger.info("Initial posterior: \(ranked, privacy: .public)")
        }
    }
}
