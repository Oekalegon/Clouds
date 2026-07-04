//
//  BayesianNetworkTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

struct BayesianNetworkTests {

    /// The classic "wet grass" textbook network: Cloudy -> Sprinkler,
    /// Cloudy -> Rain, {Sprinkler, Rain} -> WetGrass. Published posterior
    /// values (e.g. P(Rain=T | WetGrass=T) ~= 0.7079) give an external
    /// correctness reference beyond self-consistency.
    private func makeWetGrassNetwork() throws -> BayesianNetwork {
        let cloudy = BayesianNetworkNode(id: "Cloudy", states: ["T", "F"])
        let sprinkler = BayesianNetworkNode(id: "Sprinkler", states: ["T", "F"], parentIDs: ["Cloudy"])
        let rain = BayesianNetworkNode(id: "Rain", states: ["T", "F"], parentIDs: ["Cloudy"])
        let wetGrass = BayesianNetworkNode(id: "WetGrass", states: ["T", "F"], parentIDs: ["Sprinkler", "Rain"])

        let cpts: [NodeID: ConditionalProbabilityTable] = [
            "Cloudy": ConditionalProbabilityTable([
                Assignment(): ["T": 0.5, "F": 0.5]
            ]),
            "Sprinkler": ConditionalProbabilityTable([
                Assignment(["Cloudy": "T"]): ["T": 0.1, "F": 0.9],
                Assignment(["Cloudy": "F"]): ["T": 0.5, "F": 0.5]
            ]),
            "Rain": ConditionalProbabilityTable([
                Assignment(["Cloudy": "T"]): ["T": 0.8, "F": 0.2],
                Assignment(["Cloudy": "F"]): ["T": 0.2, "F": 0.8]
            ]),
            "WetGrass": ConditionalProbabilityTable([
                Assignment(["Sprinkler": "T", "Rain": "T"]): ["T": 0.99, "F": 0.01],
                Assignment(["Sprinkler": "T", "Rain": "F"]): ["T": 0.90, "F": 0.10],
                Assignment(["Sprinkler": "F", "Rain": "T"]): ["T": 0.90, "F": 0.10],
                Assignment(["Sprinkler": "F", "Rain": "F"]): ["T": 0.00, "F": 1.00]
            ])
        ]

        return try BayesianNetwork(nodes: [cloudy, sprinkler, rain, wetGrass], cpts: cpts)
    }

    @Test func posteriorMatchesPublishedWetGrassValues() async throws {
        let network = try makeWetGrassNetwork()

        let rainGivenWetGrass = try network.posterior(of: "Rain", given: ["WetGrass": "T"])
        #expect(abs(rainGivenWetGrass["T"]! - 0.7079) < 0.001)

        let sprinklerGivenWetGrass = try network.posterior(of: "Sprinkler", given: ["WetGrass": "T"])
        #expect(abs(sprinklerGivenWetGrass["T"]! - 0.4298) < 0.001)
    }

    @Test func posteriorWithNoEvidenceMatchesPriorMarginal() async throws {
        let network = try makeWetGrassNetwork()

        let wetGrass = try network.posterior(of: "WetGrass", given: [:])
        #expect(abs(wetGrass["T"]! - 0.6471) < 0.001)
    }

    @Test func posteriorDistributionSumsToOne() async throws {
        let network = try makeWetGrassNetwork()

        let distribution = try network.posterior(of: "Cloudy", given: ["WetGrass": "T"])
        let total = distribution.values.reduce(0, +)
        #expect(abs(total - 1.0) < 1e-9)
    }

    @Test func posteriorThrowsOnImpossibleEvidence() async throws {
        let network = try makeWetGrassNetwork()

        #expect(throws: BayesianNetworkError.zeroEvidenceProbability) {
            try network.posterior(of: "Cloudy", given: ["WetGrass": "T", "Sprinkler": "F", "Rain": "F"])
        }
    }

    @Test func initThrowsOnCyclicGraph() async throws {
        let a = BayesianNetworkNode(id: "A", states: ["T", "F"], parentIDs: ["B"])
        let b = BayesianNetworkNode(id: "B", states: ["T", "F"], parentIDs: ["A"])
        let cpts: [NodeID: ConditionalProbabilityTable] = [
            "A": ConditionalProbabilityTable([Assignment(["B": "T"]): ["T": 0.5, "F": 0.5], Assignment(["B": "F"]): ["T": 0.5, "F": 0.5]]),
            "B": ConditionalProbabilityTable([Assignment(["A": "T"]): ["T": 0.5, "F": 0.5], Assignment(["A": "F"]): ["T": 0.5, "F": 0.5]])
        ]

        #expect(throws: BayesianNetworkError.cyclicGraph) {
            try BayesianNetwork(nodes: [a, b], cpts: cpts)
        }
    }

    @Test func initThrowsOnIncompleteCPT() async throws {
        let a = BayesianNetworkNode(id: "A", states: ["T", "F"])
        #expect(throws: BayesianNetworkError.incompleteCPT(node: "A")) {
            try BayesianNetwork(nodes: [a], cpts: [:])
        }
    }

    @Test func initThrowsWhenCPTRowDoesNotSumToOne() async throws {
        let a = BayesianNetworkNode(id: "A", states: ["T", "F"])
        let cpts: [NodeID: ConditionalProbabilityTable] = [
            "A": ConditionalProbabilityTable([Assignment(): ["T": 0.4, "F": 0.4]])
        ]

        #expect(throws: BayesianNetworkError.invalidProbabilities(node: "A", parents: Assignment())) {
            try BayesianNetwork(nodes: [a], cpts: cpts)
        }
    }

    @Test func initThrowsOnUnknownParent() async throws {
        let a = BayesianNetworkNode(id: "A", states: ["T", "F"], parentIDs: ["Ghost"])
        let cpts: [NodeID: ConditionalProbabilityTable] = [
            "A": ConditionalProbabilityTable([Assignment(["Ghost": "T"]): ["T": 0.5, "F": 0.5], Assignment(["Ghost": "F"]): ["T": 0.5, "F": 0.5]])
        ]

        #expect(throws: BayesianNetworkError.unknownParent(node: "A", parent: "Ghost")) {
            try BayesianNetwork(nodes: [a], cpts: cpts)
        }
    }

    /// A target node caused directly by one question and independent of
    /// another: `bestNextQuestion` should prefer the informative one.
    private func makeQuestionSelectionNetwork() throws -> BayesianNetwork {
        let target = BayesianNetworkNode(id: "Target", states: ["A", "B"], parentIDs: ["Informative"])
        let informative = BayesianNetworkNode(id: "Informative", states: ["T", "F"])
        let irrelevant = BayesianNetworkNode(id: "Irrelevant", states: ["T", "F"])

        let cpts: [NodeID: ConditionalProbabilityTable] = [
            "Target": ConditionalProbabilityTable([
                Assignment(["Informative": "T"]): ["A": 0.95, "B": 0.05],
                Assignment(["Informative": "F"]): ["A": 0.05, "B": 0.95]
            ]),
            "Informative": ConditionalProbabilityTable([
                Assignment(): ["T": 0.5, "F": 0.5]
            ]),
            "Irrelevant": ConditionalProbabilityTable([
                Assignment(): ["T": 0.5, "F": 0.5]
            ])
        ]

        return try BayesianNetwork(nodes: [target, informative, irrelevant], cpts: cpts)
    }

    @Test func bestNextQuestionPicksTheInformativeCandidate() async throws {
        let network = try makeQuestionSelectionNetwork()

        let best = try network.bestNextQuestion(among: ["Informative", "Irrelevant"], forTargets: ["Target"], given: [:])
        #expect(best == "Informative")

        let informativeGain = try network.expectedInformationGain(ofAsking: "Informative", forTargets: ["Target"], given: [:])
        let irrelevantGain = try network.expectedInformationGain(ofAsking: "Irrelevant", forTargets: ["Target"], given: [:])

        #expect(informativeGain > 0.01)
        #expect(abs(irrelevantGain) < 1e-9)
    }

    @Test func bestNextQuestionReturnsNilForEmptyCandidates() async throws {
        let network = try makeQuestionSelectionNetwork()
        let best = try network.bestNextQuestion(among: [], forTargets: ["Target"], given: [:])
        #expect(best == nil)
    }
}
