// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct Quadrant: Sendable, Equatable {
    public let left: Double
    public let right: Double

    public init(heading: Double) {
        left = SSGeoMath.normalizedDegrees(heading - 45.0)
        right = SSGeoMath.normalizedDegrees(heading + 45.0)
    }

    public func contains(_ heading: Double) -> Bool {
        let wrappedHeading = SSGeoMath.normalizedDegrees(heading)

        if wrappedHeading >= left && wrappedHeading < right {
            return true
        } else if right < left && (wrappedHeading >= left || wrappedHeading < right) {
            return true
        }

        return false
    }
}

public enum CompassDirection: Int, Sendable, CaseIterable {
    case north = 0
    case east = 1
    case south = 2
    case west = 3
    case unknown = 4

    public static let allDirections: [CompassDirection] = [.north, .east, .south, .west]

    public static func quadrants(forHeading heading: Double) -> [Quadrant] {
        let quadrantIndex = Int(SSGeoMath.normalizedDegrees(heading + 45.0)) / 90
        let northHeading = quadrantIndex == 0
            ? SSGeoMath.normalizedDegrees(heading)
            : SSGeoMath.normalizedDegrees(heading + 90.0 * Double(4 - quadrantIndex))

        return [
            Quadrant(heading: northHeading),
            Quadrant(heading: northHeading + 90.0),
            Quadrant(heading: northHeading + 180.0),
            Quadrant(heading: northHeading + 270.0)
        ]
    }

    public static func from(bearing: Double, quadrants: [Quadrant]) -> CompassDirection {
        guard let index = quadrants.firstIndex(where: { $0.contains(bearing) }), index < 4 else {
            return .unknown
        }

        return CompassDirection(rawValue: index) ?? .unknown
    }

    public static func from(heading: Double) -> CompassDirection {
        from(bearing: heading, quadrants: quadrants(forHeading: heading))
    }
}
