//
//  CloudGenus.swift
//  Clouds
//
//  Created by Dieudonné Willems on 04/07/2026.
//

import Foundation

/// The 10 WMO cloud genera. `rawValue` matches the "Genus" node's state
/// ids in `genus-network.json` (WMO abbreviations); `displayName` is the
/// human-readable name shown in the UI and saved to `CloudObservation`.
enum CloudGenus: String, CaseIterable, Sendable {
    case cirrus = "Ci"
    case cirrocumulus = "Cc"
    case cirrostratus = "Cs"
    case altocumulus = "Ac"
    case altostratus = "As"
    case nimbostratus = "Ns"
    case stratocumulus = "Sc"
    case stratus = "St"
    case cumulus = "Cu"
    case cumulonimbus = "Cb"

    var displayName: String {
        switch self {
        case .cirrus: "Cirrus"
        case .cirrocumulus: "Cirrocumulus"
        case .cirrostratus: "Cirrostratus"
        case .altocumulus: "Altocumulus"
        case .altostratus: "Altostratus"
        case .nimbostratus: "Nimbostratus"
        case .stratocumulus: "Stratocumulus"
        case .stratus: "Stratus"
        case .cumulus: "Cumulus"
        case .cumulonimbus: "Cumulonimbus"
        }
    }
}
