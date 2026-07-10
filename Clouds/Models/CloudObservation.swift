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
    /// Detected supplementary features (Mamma, Arcus, ...) and accessory
    /// clouds (Pileus, Velum, ...) are distinct WMO categories, so they're
    /// kept as separate lists rather than merged into one field.
    var supplementaryFeatures: [String]
    var accessoryClouds: [String]
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
        supplementaryFeatures: [String] = [],
        accessoryClouds: [String] = [],
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
        self.supplementaryFeatures = supplementaryFeatures
        self.accessoryClouds = accessoryClouds
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.skyConditions = skyConditions
    }

    /// Matches observations not linked to any sky condition, e.g. those
    /// identified from an old library photo. Shared between the history
    /// feed's query and its tests, so the tested predicate is the one the
    /// view actually runs.
    static var standalonePredicate: Predicate<CloudObservation> {
        #Predicate { $0.skyConditions == nil }
    }
}
