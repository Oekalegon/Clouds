//
//  QuestionCategories.swift
//  Clouds
//
//  Created by Dieudonné Willems on 09/07/2026.
//

import Foundation

/// Which askable questions are WMO Supplementary Features / Accessory
/// Clouds rather than genus-identification questions. Loaded from
/// `QuestionCategories.json` rather than encoded as a "kind" field on
/// `QuestionDefinition`/`BayesianNetworkFileNode` (CLD-3's decision to keep
/// those schemas free of a classification field still holds) — this is a
/// separate axis (how a question should be *used* in the Q&A flow, not
/// what it *is* structurally), and every id here is still a plain G -> Q
/// node like any other question.
struct QuestionCategories: Decodable {
    let supplementaryFeatures: [NodeID]
    let accessoryClouds: [NodeID]
}
