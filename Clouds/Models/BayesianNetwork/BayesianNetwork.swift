//
//  BayesianNetwork.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

enum BayesianNetworkError: Error, Equatable {
    case duplicateNode(NodeID)
    case unknownParent(node: NodeID, parent: NodeID)
    case unknownNode(NodeID)
    case cyclicGraph
    case incompleteCPT(node: NodeID)
    case invalidProbabilities(node: NodeID, parents: Assignment)
    case zeroEvidenceProbability
}

/// A Bayesian Network: a directed acyclic graph of nodes, each with a
/// conditional probability table over its parents' states.
struct BayesianNetwork {
    let nodes: [NodeID: BayesianNetworkNode]
    let cpts: [NodeID: ConditionalProbabilityTable]

    /// Nodes in topological order (parents before children).
    let topologicalOrder: [NodeID]

    private static let probabilityTolerance = 1e-6

    init(nodes: [BayesianNetworkNode], cpts: [NodeID: ConditionalProbabilityTable]) throws {
        var nodesByID: [NodeID: BayesianNetworkNode] = [:]
        for node in nodes {
            guard nodesByID[node.id] == nil else {
                throw BayesianNetworkError.duplicateNode(node.id)
            }
            nodesByID[node.id] = node
        }

        for node in nodes {
            for parentID in node.parentIDs {
                guard nodesByID[parentID] != nil else {
                    throw BayesianNetworkError.unknownParent(node: node.id, parent: parentID)
                }
            }
        }

        let order = try Self.topologicalSort(of: nodes)

        for node in nodes {
            try Self.validateCPT(for: node, nodesByID: nodesByID, cpts: cpts)
        }

        self.nodes = nodesByID
        self.cpts = cpts
        self.topologicalOrder = order
    }

    private static func topologicalSort(of nodes: [BayesianNetworkNode]) throws -> [NodeID] {
        var remainingParents: [NodeID: Set<NodeID>] = [:]
        for node in nodes {
            remainingParents[node.id] = Set(node.parentIDs)
        }

        var order: [NodeID] = []
        var ready = nodes.filter { $0.parentIDs.isEmpty }.map(\.id)

        while !ready.isEmpty {
            let id = ready.removeFirst()
            order.append(id)
            for node in nodes where remainingParents[node.id]?.contains(id) == true {
                remainingParents[node.id]?.remove(id)
                if remainingParents[node.id]?.isEmpty == true {
                    ready.append(node.id)
                }
            }
        }

        guard order.count == nodes.count else {
            throw BayesianNetworkError.cyclicGraph
        }
        return order
    }

    /// Every combination of the given parent nodes' states, as `Assignment`s.
    private static func parentAssignments(for parentIDs: [NodeID], nodesByID: [NodeID: BayesianNetworkNode]) -> [Assignment] {
        guard !parentIDs.isEmpty else { return [Assignment()] }

        var combinations: [[NodeID: StateID]] = [[:]]
        for parentID in parentIDs {
            let states = nodesByID[parentID]?.states ?? []
            combinations = combinations.flatMap { partial in
                states.map { state in
                    var next = partial
                    next[parentID] = state
                    return next
                }
            }
        }
        return combinations.map(Assignment.init)
    }

    private static func validateCPT(
        for node: BayesianNetworkNode,
        nodesByID: [NodeID: BayesianNetworkNode],
        cpts: [NodeID: ConditionalProbabilityTable]
    ) throws {
        guard let cpt = cpts[node.id] else {
            throw BayesianNetworkError.incompleteCPT(node: node.id)
        }

        for parentAssignment in parentAssignments(for: node.parentIDs, nodesByID: nodesByID) {
            guard let distribution = cpt.distribution(givenParents: parentAssignment) else {
                throw BayesianNetworkError.incompleteCPT(node: node.id)
            }

            let states = Set(distribution.keys)
            guard states == Set(node.states) else {
                throw BayesianNetworkError.invalidProbabilities(node: node.id, parents: parentAssignment)
            }

            let total = distribution.values.reduce(0, +)
            guard abs(total - 1) < probabilityTolerance else {
                throw BayesianNetworkError.invalidProbabilities(node: node.id, parents: parentAssignment)
            }
        }
    }
}
