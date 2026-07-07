//
//  HistoryEntry.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Foundation
import SwiftData

/// One entry in the mixed history feed: either a whole sky condition
/// (rendered as a section with its observations) or a standalone
/// observation that isn't linked to one, such as an identification from an
/// old library photo.
enum HistoryEntry: Identifiable {
    case skyConditions(SkyConditions)
    case observation(CloudObservation)

    var id: PersistentIdentifier {
        switch self {
        case .skyConditions(let skyConditions): skyConditions.persistentModelID
        case .observation(let observation): observation.persistentModelID
        }
    }

    var date: Date {
        switch self {
        case .skyConditions(let skyConditions): skyConditions.date
        case .observation(let observation): observation.date
        }
    }

    /// Merges both kinds into one feed, most recent first.
    static func chronological(
        skyConditions: [SkyConditions],
        standaloneObservations: [CloudObservation]
    ) -> [HistoryEntry] {
        (skyConditions.map(Self.skyConditions) + standaloneObservations.map(Self.observation))
            .sorted { $0.date > $1.date }
    }
}
