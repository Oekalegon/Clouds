//
//  BayesianNetwork+Inference.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// Brute-force (enumeration) inference over a `BayesianNetwork`. Exact but
/// exponential in the number of non-evidence nodes — acceptable for the
/// small networks this app uses; a junction-tree algorithm can replace this
/// later without changing the public API.
extension BayesianNetwork {
    /// The joint posterior distribution over `targets`, marginalizing out
    /// every other non-evidence node, given `evidence`.
    ///
    /// Only enumerates free nodes in the *ancestral graph* of
    /// `targets ∪ evidence` (i.e. those nodes plus their ancestors).
    /// Any other free node is a "barren" node w.r.t. this query — it has
    /// no path to a target or evidence node, so marginalizing it out
    /// always contributes a factor of 1 (its CPT rows sum to 1 over
    /// states) and can be skipped entirely rather than enumerated. This
    /// is an exact simplification (not an approximation): for a
    /// star-shaped network like this app's (one classification root,
    /// many independent question leaves), it collapses an
    /// exponential-in-the-number-of-unanswered-questions enumeration down
    /// to just the target's own states once none of those questions are
    /// themselves targets or evidence.
    func jointPosterior(over targets: [NodeID], given evidence: [NodeID: StateID] = [:]) throws -> [Assignment: Double] {
        for id in targets + Array(evidence.keys) {
            guard nodes[id] != nil else { throw BayesianNetworkError.unknownNode(id) }
        }

        let fixed = Assignment(evidence)
        let relevant = ancestralClosure(of: Set(targets).union(evidence.keys))
        let freeNodes = topologicalOrder.filter { evidence[$0] == nil && relevant.contains($0) }

        var totals: [Assignment: Double] = [:]
        var grandTotal = 0.0

        enumerateAssignments(of: freeNodes, fixed: fixed) { full in
            let probability = jointProbability(of: full)
            guard probability > 0 else { return }
            totals[full.restricted(to: targets), default: 0] += probability
            grandTotal += probability
        }

        guard grandTotal > 0 else {
            throw BayesianNetworkError.zeroEvidenceProbability
        }

        return totals.mapValues { $0 / grandTotal }
    }

    /// The marginal posterior distribution over a single node's states.
    func posterior(of node: NodeID, given evidence: [NodeID: StateID] = [:]) throws -> [StateID: Double] {
        let joint = try jointPosterior(over: [node], given: evidence)
        var result: [StateID: Double] = [:]
        for (assignment, probability) in joint {
            guard let state = assignment[node] else { continue }
            result[state, default: 0] += probability
        }
        return result
    }

    /// The expected reduction in entropy of `targets` from asking
    /// `candidate` next, given the current `evidence`.
    func expectedInformationGain(
        ofAsking candidate: NodeID,
        forTargets targets: [NodeID],
        given evidence: [NodeID: StateID] = [:]
    ) throws -> Double {
        let currentEntropy = Self.entropy(of: try jointPosterior(over: targets, given: evidence))
        let candidateDistribution = try posterior(of: candidate, given: evidence)

        var expectedPosteriorEntropy = 0.0
        for (state, probability) in candidateDistribution where probability > 0 {
            var hypotheticalEvidence = evidence
            hypotheticalEvidence[candidate] = state
            let hypotheticalJoint = try jointPosterior(over: targets, given: hypotheticalEvidence)
            expectedPosteriorEntropy += probability * Self.entropy(of: hypotheticalJoint)
        }

        return currentEntropy - expectedPosteriorEntropy
    }

    /// The candidate node whose answer is expected to reduce uncertainty
    /// about `targets` the most, or `nil` if `candidates` is empty.
    func bestNextQuestion(
        among candidates: [NodeID],
        forTargets targets: [NodeID],
        given evidence: [NodeID: StateID] = [:]
    ) throws -> NodeID? {
        var best: (id: NodeID, gain: Double)?
        for candidate in candidates {
            let gain = try expectedInformationGain(ofAsking: candidate, forTargets: targets, given: evidence)
            if best == nil || gain > best!.gain {
                best = (candidate, gain)
            }
        }
        return best?.id
    }

    /// Shannon entropy, in bits, of a discrete distribution.
    static func entropy<Key>(of distribution: [Key: Double]) -> Double {
        distribution.values.reduce(0) { total, probability in
            guard probability > 0 else { return total }
            return total - probability * log2(probability)
        }
    }

    /// The full joint probability of a complete assignment (one state per
    /// node), as the product of each node's `P(state | parent states)`.
    private func jointProbability(of assignment: Assignment) -> Double {
        var probability = 1.0
        for nodeID in topologicalOrder {
            guard let node = nodes[nodeID], let cpt = cpts[nodeID], let state = assignment[nodeID] else { continue }
            probability *= cpt.probability(of: state, givenParents: assignment.restricted(to: node.parentIDs))
            if probability == 0 { break }
        }
        return probability
    }

    /// `nodeIDs` plus every ancestor reachable by following `parentIDs`
    /// upward.
    private func ancestralClosure(of nodeIDs: Set<NodeID>) -> Set<NodeID> {
        var closure = nodeIDs
        var frontier = Array(nodeIDs)

        while !frontier.isEmpty {
            var next: [NodeID] = []
            for id in frontier {
                guard let node = nodes[id] else { continue }
                for parentID in node.parentIDs where !closure.contains(parentID) {
                    closure.insert(parentID)
                    next.append(parentID)
                }
            }
            frontier = next
        }

        return closure
    }

    /// Calls `body` with every full assignment formed by combining `fixed`
    /// with each combination of states for `nodeIDs`.
    private func enumerateAssignments(of nodeIDs: [NodeID], fixed: Assignment, body: (Assignment) -> Void) {
        func recurse(index: Int, current: [NodeID: StateID]) {
            guard index < nodeIDs.count else {
                body(Assignment(current).merging(fixed))
                return
            }
            let nodeID = nodeIDs[index]
            for state in nodes[nodeID]?.states ?? [] {
                var next = current
                next[nodeID] = state
                recurse(index: index + 1, current: next)
            }
        }
        recurse(index: 0, current: [:])
    }
}
