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
    var genus: String?
    var species: String?
    var variety: String?
    var specialFeature: String?
    @Attribute(.externalStorage) var photoData: Data?

    init(
        date: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        genus: String? = nil,
        species: String? = nil,
        variety: String? = nil,
        specialFeature: String? = nil,
        photoData: Data? = nil
    ) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.genus = genus
        self.species = species
        self.variety = variety
        self.specialFeature = specialFeature
        self.photoData = photoData
    }

    static func sectionKey(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}
