//
//  SkyConditions.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Foundation
import SwiftData

/// The state of the whole sky at a moment in time: total cloud cover plus
/// the WeatherKit conditions. Several observations can share one instance,
/// since multiple cloud types are often present (and identified) at the
/// same time.
@Model
final class SkyConditions {
    /// Conditions at the time of observation, from WeatherKit. Stored as a
    /// single `Codable` property (SwiftData persists these natively) rather
    /// than flattened scalar fields, since it carries everything
    /// `CurrentWeather` exposes.
    struct WeatherSnapshot: Codable {
        var date: Date
        var temperatureCelsius: Double
        var apparentTemperatureCelsius: Double
        var humidity: Double
        var dewPointCelsius: Double
        var pressureHectopascals: Double
        var pressureTrend: String
        var cloudCover: Double
        var visibilityMeters: Double
        var uvIndex: Int
        var isDaylight: Bool
        var condition: String
        var symbolName: String
        var windSpeedKph: Double
        var windGustKph: Double?
        var windDirectionDegrees: Double
        var windCompassDirection: String
    }

    var date: Date
    /// Total cloud cover in eighths of the sky (oktas), 0...8.
    /// `nil` when the cover wasn't recorded or the sky was obscured.
    var cloudCoverEighths: Int?
    /// WMO okta 9: the sky can't be judged because it is obscured by fog,
    /// smoke, haze, etc.
    var isSkyObscured: Bool
    var weather: WeatherSnapshot?
    @Relationship(deleteRule: .nullify, inverse: \CloudObservation.skyConditions)
    var observations: [CloudObservation] = []

    init(
        date: Date = .now,
        cloudCoverEighths: Int? = nil,
        isSkyObscured: Bool = false,
        weather: WeatherSnapshot? = nil
    ) {
        self.date = date
        // An obscured sky has no judgeable cover; normalising here keeps
        // the invariant out of the callers' hands.
        self.cloudCoverEighths = isSkyObscured ? nil : cloudCoverEighths
        self.isSkyObscured = isSkyObscured
        self.weather = weather
    }

    /// Observations under this sky, oldest first — the order they were
    /// added during the session.
    var observationsByDate: [CloudObservation] {
        observations.sorted { $0.date < $1.date }
    }

    /// The recorded cover as a display line, e.g. "3/8 cover" or
    /// "Sky obscured"; `nil` when nothing was recorded.
    var coverLine: String? {
        guard let cover = cloudCoverDescription else { return nil }
        return isSkyObscured ? cover : String(localized: "\(cover) cover")
    }

    /// One line summarising these conditions for lists, e.g.
    /// "3/8 cover · 21°C, Partly Cloudy" — whichever parts were recorded;
    /// `nil` when there is nothing to show.
    var summaryLine: String? {
        var parts: [String] = []
        if let coverLine {
            parts.append(coverLine)
        }
        if let weather {
            parts.append("\(Int(weather.temperatureCelsius.rounded()))°C, \(weather.condition)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// User-facing summary of the recorded cover, e.g. "3/8" or
    /// "Sky obscured"; `nil` when nothing was recorded.
    var cloudCoverDescription: String? {
        if isSkyObscured { return String(localized: "Sky obscured") }
        guard let cloudCoverEighths else { return nil }
        return "\(cloudCoverEighths)/8"
    }

    /// The standard okta bucket name for a given cover, used as a caption
    /// under the numeric value in the dial.
    static func coverName(forEighths eighths: Int) -> String {
        switch eighths {
        case ...0: String(localized: "Clear")
        case 1...2: String(localized: "Few clouds")
        case 3...4: String(localized: "Scattered clouds")
        case 5...7: String(localized: "Broken clouds")
        default: String(localized: "Overcast")
        }
    }
}
