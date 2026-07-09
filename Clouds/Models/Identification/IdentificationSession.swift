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
    private static let logger = Logger(subsystem: "no.oekalegon.Clouds", category: "Identification")

    /// Below the genus-network content's calibrated ceiling for a highly
    /// non-applicable question (0.85 — see `GenusNetworkContentTests`):
    /// a default at or above that ceiling would mean the skip-question
    /// filter below can mathematically never trigger, since a node's
    /// marginal `P(NotApplicable | evidence)` is a probability-weighted
    /// average of its per-genus CPT values and so can never exceed the
    /// highest of those values.
    nonisolated static let defaultNotApplicableThreshold: Double = 0.65

    /// A supplementary-feature/accessory-cloud question is only worth
    /// asking, once the genus is settled, if that genus is at least
    /// plausibly associated with it — this is the "Possible" calibration
    /// floor (0.25) halved, so a merely-"Possible" feature still clears it
    /// but a completely unlabelled genus's ~0.05 baseline doesn't.
    nonisolated static let defaultFeatureRelevanceThreshold: Double = 0.15

    private let catalog: IdentificationCatalog
    private let confidenceThreshold: Double
    private let notApplicableThreshold: Double
    private let featureRelevanceThreshold: Double

    private(set) var history: [AnsweredQuestion] = []
    private(set) var currentIndex = 0

    private(set) var currentQuestionID: NodeID?
    private(set) var posterior: [StateID: Double] = [:]
    private(set) var isFinished = false
    private(set) var isComputingNextQuestion = false

    /// Whether genus identification itself has concluded (confidence
    /// reached, or every genus-identification question exhausted) — once
    /// true, `refresh` moves on to asking about supplementary features and
    /// accessory clouds still plausible for the determined genus, rather
    /// than finishing the session outright.
    private var isGenusPhaseComplete = false

    init(
        catalog: IdentificationCatalog = .shared,
        confidenceThreshold: Double = 0.9,
        notApplicableThreshold: Double = IdentificationSession.defaultNotApplicableThreshold,
        featureRelevanceThreshold: Double = IdentificationSession.defaultFeatureRelevanceThreshold
    ) {
        self.catalog = catalog
        self.confidenceThreshold = confidenceThreshold
        self.notApplicableThreshold = notApplicableThreshold
        self.featureRelevanceThreshold = featureRelevanceThreshold
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

    /// Supplementary features actually observed this session, in the
    /// order they were asked — every answered question in
    /// `catalog.supplementaryFeatureNodeIDs` whose answer wasn't "No"
    /// (Incus's "NotApplicable" doesn't count as observed either).
    var detectedSupplementaryFeatures: [NodeID] {
        history.filter { isDetected($0, in: catalog.supplementaryFeatureNodeIDs) }.map(\.questionID)
    }

    /// Accessory clouds actually observed this session — see
    /// `detectedSupplementaryFeatures`.
    var detectedAccessoryClouds: [NodeID] {
        history.filter { isDetected($0, in: catalog.accessoryCloudNodeIDs) }.map(\.questionID)
    }

    private func isDetected(_ answered: AnsweredQuestion, in category: [NodeID]) -> Bool {
        category.contains(answered.questionID)
            && answered.answer != "No"
            && answered.answer != QuestionDefinition.notApplicableStateID
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
                // Changing an earlier genus-identification answer can
                // reopen genus identification (confidence/candidates may
                // no longer hold); changing a later feature/accessory-
                // cloud answer can't, since genus was already settled
                // before that question was ever asked.
                if catalog.genusIdentificationNodeIDs.contains(questionID) {
                    isGenusPhaseComplete = false
                }
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

        if !isGenusPhaseComplete {
            let remainingGenusCandidates = catalog.genusIdentificationNodeIDs.filter { evidence[$0] == nil }
            let isConfident = (posterior.values.max() ?? 0) >= confidenceThreshold

            if !isConfident && !remainingGenusCandidates.isEmpty {
                await pickNextGenusQuestion(among: remainingGenusCandidates, evidence: evidence, network: network)
                return
            }
            isGenusPhaseComplete = true
        }

        await pickNextFeatureQuestion(evidence: evidence, network: network)
    }

    /// Phase 1: pick the genus-identification question with the highest
    /// expected information gain about "Genus" (unchanged behaviour from
    /// before CLD-9's supplementary features/accessory clouds).
    private func pickNextGenusQuestion(
        among remainingCandidates: [NodeID], evidence: [NodeID: StateID], network: BayesianNetwork
    ) async {
        isComputingNextQuestion = true
        let targets = [Self.targetNodeID]
        let notApplicableThreshold = self.notApplicableThreshold
        let expectedIndex = currentIndex
        let next = await Task.detached {
            let applicableCandidates = remainingCandidates.filter { candidateID in
                let notApplicableProbability = (try? network.posterior(of: candidateID, given: evidence))?[
                    QuestionDefinition.notApplicableStateID
                ] ?? 0
                return notApplicableProbability < notApplicableThreshold
            }
            return try? network.bestNextQuestion(among: applicableCandidates, forTargets: targets, given: evidence)
        }.value

        // The user may have navigated (goBack/goForward) while this
        // computation was in flight, which already ran its own refresh()
        // synchronously. Applying this now-stale result would clobber
        // that more recent, correct state.
        guard currentIndex == expectedIndex else { return }

        if let next {
            currentQuestionID = next
            isFinished = false
            isComputingNextQuestion = false
        } else {
            // No genus question was worth asking (every remaining
            // candidate was filtered out as not-applicable) — move on to
            // supplementary features/accessory clouds rather than
            // finishing outright.
            isGenusPhaseComplete = true
            isComputingNextQuestion = false
            await pickNextFeatureQuestion(evidence: evidence, network: network)
        }
    }

    /// Phase 2: once the genus is settled, ask about supplementary
    /// features/accessory clouds still plausible for it — skipping ones
    /// this genus essentially never has (below `featureRelevanceThreshold`)
    /// rather than ranking by information gain, since these no longer
    /// need to move "Genus"'s posterior at all.
    private func pickNextFeatureQuestion(evidence: [NodeID: StateID], network: BayesianNetwork) async {
        let remainingFeatureCandidates = (catalog.supplementaryFeatureNodeIDs + catalog.accessoryCloudNodeIDs)
            .filter { evidence[$0] == nil }

        guard !remainingFeatureCandidates.isEmpty else {
            isFinished = true
            currentQuestionID = nil
            isComputingNextQuestion = false
            logTestSetEntry()
            return
        }

        isComputingNextQuestion = true
        let featureRelevanceThreshold = self.featureRelevanceThreshold
        let expectedIndex = currentIndex
        let next = await Task.detached {
            remainingFeatureCandidates.first { candidateID in
                let distribution = (try? network.posterior(of: candidateID, given: evidence)) ?? [:]
                let positiveProbability = distribution
                    .filter { $0.key != "No" && $0.key != QuestionDefinition.notApplicableStateID }
                    .values
                    .reduce(0, +)
                return positiveProbability >= featureRelevanceThreshold
            }
        }.value

        guard currentIndex == expectedIndex else { return }

        currentQuestionID = next
        isFinished = next == nil
        isComputingNextQuestion = false
        if isFinished {
            logTestSetEntry()
        }
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

    /// TEMPORARY (CLD-9 debugging): dumps a ready-to-paste test-set entry
    /// once the session finishes — every question asked with its answer as
    /// a Swift evidence dict, plus the resulting genus posterior — so real
    /// Q&A walks can be captured straight into `GenusNetworkContentTests`
    /// while the network's calibration is still being tuned.
    private func logTestSetEntry() {
        let evidence = history
            .map { "\"\($0.questionID)\": \"\($0.answer)\"" }
            .joined(separator: ", ")
        let ranked = posterior
            .sorted { $0.value > $1.value }
            .map { state, probability in
                let name = CloudGenus(rawValue: state)?.displayName ?? state
                return "\(name): \(String(format: "%.1f", probability * 100))%"
            }
            .joined(separator: ", ")
        let features = detectedSupplementaryFeatures.isEmpty ? "none" : detectedSupplementaryFeatures.joined(separator: ", ")
        let accessory = detectedAccessoryClouds.isEmpty ? "none" : detectedAccessoryClouds.joined(separator: ", ")

        Self.logger.info("""
        TESTSET entry:
        let evidence: [NodeID: StateID] = [\(evidence, privacy: .public)]
        // Posterior: \(ranked, privacy: .public)
        // Supplementary features: \(features, privacy: .public)
        // Accessory clouds: \(accessory, privacy: .public)
        """)
    }
}
