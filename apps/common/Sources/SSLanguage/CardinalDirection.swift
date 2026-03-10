// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum CardinalDirection: String, CaseIterable, Sendable {
    case north = "n"
    case northEast = "ne"
    case east = "e"
    case southEast = "se"
    case south = "s"
    case southWest = "sw"
    case west = "w"
    case northWest = "nw"
}

public extension CardinalDirection {
    init?(direction: Double) {
        guard direction >= 0.0 && direction <= 360.0 else {
            return nil
        }

        let allDirections = CardinalDirection.allCases
        let angularWindowRange = 360.0 / Double(allDirections.count)
        let halfAngularWindowRange = angularWindowRange / 2.0
        let adjustedDirection = fmod(direction.normalizedDegrees + halfAngularWindowRange, 360.0)
        let directionIndex = Int(adjustedDirection / angularWindowRange)
        self = allDirections[directionIndex]
    }

    func localizedString(locale: Locale) -> String {
        let key: String
        switch self {
        case .north:
            key = "directions.cardinal.north"
        case .northEast:
            key = "directions.cardinal.north_east"
        case .east:
            key = "directions.cardinal.east"
        case .southEast:
            key = "directions.cardinal.south_east"
        case .south:
            key = "directions.cardinal.south"
        case .southWest:
            key = "directions.cardinal.south_west"
        case .west:
            key = "directions.cardinal.west"
        case .northWest:
            key = "directions.cardinal.north_west"
        }

        return LanguageLocalizer.localizedString(key, locale: locale)
    }

    func localizedAbbreviatedString(locale: Locale) -> String {
        let key: String
        switch self {
        case .north:
            key = "directions.cardinal.north.abb"
        case .northEast:
            key = "directions.cardinal.north_east.abb"
        case .east:
            key = "directions.cardinal.east.abb"
        case .southEast:
            key = "directions.cardinal.south_east.abb"
        case .south:
            key = "directions.cardinal.south.abb"
        case .southWest:
            key = "directions.cardinal.south_west.abb"
        case .west:
            key = "directions.cardinal.west.abb"
        case .northWest:
            key = "directions.cardinal.north_west.abb"
        }

        return LanguageLocalizer.localizedString(key, locale: locale)
    }
}
