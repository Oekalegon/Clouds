//
//  BayesianNetworkFileTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Testing
import Foundation
@testable import Clouds

struct BayesianNetworkFileTests {

    /// JSON form of the same "wet grass" textbook network used in
    /// `BayesianNetworkTests`, so decoding can be checked against the same
    /// published posterior values.
    private static let wetGrassJSON = """
    {
      "nodes": [
        {
          "id": "Cloudy",
          "states": ["T", "F"],
          "cpt": [
            { "distribution": { "T": 0.5, "F": 0.5 } }
          ]
        },
        {
          "id": "Sprinkler",
          "states": ["T", "F"],
          "parents": ["Cloudy"],
          "cpt": [
            { "given": { "Cloudy": "T" }, "distribution": { "T": 0.1, "F": 0.9 } },
            { "given": { "Cloudy": "F" }, "distribution": { "T": 0.5, "F": 0.5 } }
          ]
        },
        {
          "id": "Rain",
          "states": ["T", "F"],
          "parents": ["Cloudy"],
          "cpt": [
            { "given": { "Cloudy": "T" }, "distribution": { "T": 0.8, "F": 0.2 } },
            { "given": { "Cloudy": "F" }, "distribution": { "T": 0.2, "F": 0.8 } }
          ]
        },
        {
          "id": "WetGrass",
          "states": ["T", "F"],
          "parents": ["Sprinkler", "Rain"],
          "cpt": [
            { "given": { "Sprinkler": "T", "Rain": "T" }, "distribution": { "T": 0.99, "F": 0.01 } },
            { "given": { "Sprinkler": "T", "Rain": "F" }, "distribution": { "T": 0.90, "F": 0.10 } },
            { "given": { "Sprinkler": "F", "Rain": "T" }, "distribution": { "T": 0.90, "F": 0.10 } },
            { "given": { "Sprinkler": "F", "Rain": "F" }, "distribution": { "T": 0.00, "F": 1.00 } }
          ]
        }
      ]
    }
    """

    private func decodeFile(_ json: String) throws -> BayesianNetworkFile {
        try JSONDecoder().decode(BayesianNetworkFile.self, from: Data(json.utf8))
    }

    @Test func decodingWetGrassNetworkProducesMatchingPosteriors() throws {
        let file = try decodeFile(Self.wetGrassJSON)
        let network = try file.makeNetwork()

        let rainGivenWetGrass = try network.posterior(of: "Rain", given: ["WetGrass": "T"])
        #expect(abs(rainGivenWetGrass["T"]! - 0.7079) < 0.001)

        let sprinklerGivenWetGrass = try network.posterior(of: "Sprinkler", given: ["WetGrass": "T"])
        #expect(abs(sprinklerGivenWetGrass["T"]! - 0.4298) < 0.001)
    }

    @Test func decodingNodeOmittingParentsAndGivenDefaultsToEmpty() throws {
        let json = """
        {
          "nodes": [
            {
              "id": "Cloudy",
              "states": ["T", "F"],
              "cpt": [
                { "distribution": { "T": 0.5, "F": 0.5 } }
              ]
            }
          ]
        }
        """
        let file = try decodeFile(json)

        #expect(file.nodes[0].parents == [])
        #expect(file.nodes[0].cpt[0].given == [:])

        let network = try file.makeNetwork()
        #expect(network.nodes["Cloudy"]?.parentIDs == [])
    }

    @Test func decodingThrowsOnDuplicateCPTRow() throws {
        let json = """
        {
          "nodes": [
            {
              "id": "Cloudy",
              "states": ["T", "F"],
              "cpt": [
                { "distribution": { "T": 0.5, "F": 0.5 } },
                { "distribution": { "T": 0.4, "F": 0.6 } }
              ]
            }
          ]
        }
        """
        let file = try decodeFile(json)

        #expect(throws: SchemaError.duplicateCPTRow(node: "Cloudy", given: Assignment())) {
            try file.makeNetwork()
        }
    }

    @Test func makeNetworkPropagatesIncompleteCPTFromEngine() throws {
        let json = """
        {
          "nodes": [
            {
              "id": "Cloudy",
              "states": ["T", "F"],
              "cpt": [
                { "distribution": { "T": 0.5, "F": 0.5 } }
              ]
            },
            {
              "id": "Sprinkler",
              "states": ["T", "F"],
              "parents": ["Cloudy"],
              "cpt": [
                { "given": { "Cloudy": "T" }, "distribution": { "T": 0.1, "F": 0.9 } }
              ]
            }
          ]
        }
        """
        let file = try decodeFile(json)

        #expect(throws: BayesianNetworkError.incompleteCPT(node: "Sprinkler")) {
            try file.makeNetwork()
        }
    }

    @Test func makeNetworkPropagatesInvalidProbabilitiesFromEngine() throws {
        let json = """
        {
          "nodes": [
            {
              "id": "Cloudy",
              "states": ["T", "F"],
              "cpt": [
                { "distribution": { "T": 0.5, "F": 0.6 } }
              ]
            }
          ]
        }
        """
        let file = try decodeFile(json)

        #expect(throws: BayesianNetworkError.invalidProbabilities(node: "Cloudy", parents: Assignment())) {
            try file.makeNetwork()
        }
    }

    @Test func decodingThrowsOnMissingRequiredField() throws {
        let json = """
        {
          "nodes": [
            {
              "id": "Cloudy",
              "cpt": [
                { "distribution": { "T": 0.5, "F": 0.5 } }
              ]
            }
          ]
        }
        """

        #expect(throws: DecodingError.self) {
            try decodeFile(json)
        }
    }
}
