//
//  CloudObservation.swift
//  Clouds
//
//  Created by Dieudonné Willems on 03/07/2026.
//

import Foundation
import SwiftData

@Model
final class CloudObservation {
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var genus: String?
    var species: String?
    var variety: String?
    var specialFeature: String?
    @Attribute(.externalStorage) var photoData: Data?
    var thumbnailData: Data?
    /// The sky-wide conditions (cloud cover, weather) this observation was
    /// made under; shared between observations when several cloud types are
    /// identified at the same time. Inverse is declared on
    /// `SkyConditions.observations`.
    var skyConditions: SkyConditions?

    init(
        date: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        genus: String? = nil,
        species: String? = nil,
        variety: String? = nil,
        specialFeature: String? = nil,
        photoData: Data? = nil,
        thumbnailData: Data? = nil,
        skyConditions: SkyConditions? = nil
    ) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.genus = genus
        self.species = species
        self.variety = variety
        self.specialFeature = specialFeature
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.skyConditions = skyConditions
    }

    static func sectionKey(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func grouped(
        _ observations: [CloudObservation],
        calendar: Calendar = .current
    ) -> [(day: Date, items: [CloudObservation])] {
        let grouped = Dictionary(grouping: observations) { sectionKey(for: $0.date, calendar: calendar) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, items: $0.value) }
    }
}
