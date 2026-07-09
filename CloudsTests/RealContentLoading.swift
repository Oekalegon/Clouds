//
//  RealContentLoading.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 09/07/2026.
//

import Foundation
@testable import Clouds

/// Shared "read the real, production JSON straight off disk" helper for
/// `GenusNetworkContentTests`, `IdentificationCatalogTests`, and
/// `IdentificationSessionTests` — not via `Bundle`, since the unit-test
/// target isn't app-hosted. Question files can live flat under
/// `Questions/` (genus-identification questions) or in one of its
/// `SupplementaryFeatures`/`AccessoryClouds` subdirectories (CLD-9); this
/// checks all three so real content additions actually get exercised
/// rather than silently skipped like a hidden/derived node.
enum RealContentLoading {
    static let resourcesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../Clouds/Resources")
        .standardizedFileURL

    private static let questionSubdirectories = ["Questions", "Questions/SupplementaryFeatures", "Questions/AccessoryClouds"]

    static func decodeNetworkFile() throws -> BayesianNetworkFile {
        let url = resourcesURL.appendingPathComponent("BayesianNetwork/genus-network.json")
        return try JSONDecoder().decode(BayesianNetworkFile.self, from: Data(contentsOf: url))
    }

    /// Nil if no matching file exists in any of the known subdirectories
    /// (i.e. this is a hidden/derived node, not a real missing resource).
    static func decodeQuestion(_ id: String) -> QuestionDefinition? {
        for subdirectory in questionSubdirectories {
            let url = resourcesURL.appendingPathComponent("\(subdirectory)/\(id).json")
            guard let data = try? Data(contentsOf: url) else { continue }
            return try? JSONDecoder().decode(QuestionDefinition.self, from: data)
        }
        return nil
    }

    static func decodeQuestionCategories() throws -> QuestionCategories {
        let url = resourcesURL.appendingPathComponent("QuestionCategories.json")
        return try JSONDecoder().decode(QuestionCategories.self, from: Data(contentsOf: url))
    }

    static func loadCatalog() throws -> IdentificationCatalog {
        let networkFile = try decodeNetworkFile()
        let questionIDs = networkFile.nodes.map(\.id).filter { $0 != "Genus" }
        let questionFiles = questionIDs.compactMap(decodeQuestion)
        let categories = try decodeQuestionCategories()

        return try IdentificationCatalog(
            networkFile: networkFile,
            questionFiles: questionFiles,
            supplementaryFeatureIDs: Set(categories.supplementaryFeatures),
            accessoryCloudIDs: Set(categories.accessoryClouds)
        )
    }
}
