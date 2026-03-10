// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum RelativeDirectionType: Int, Sendable {
    case combined
    case individual
    case aheadBehind
    case leftRight
}

public enum Direction: Int, Sendable {
    case behind
    case behindLeft
    case left
    case aheadLeft
    case ahead
    case aheadRight
    case right
    case behindRight
    case unknown
}

public extension Direction {
    init(from direction: Double, to otherDirection: Double, type: RelativeDirectionType = .individual) {
        let relativeDirection = direction.bearing(to: otherDirection)
        self.init(from: relativeDirection, type: type)
    }

    init(from direction: Double, type: RelativeDirectionType = .individual) {
        guard direction >= 0 else {
            self = .unknown
            return
        }

        let normalizedDirection = direction.normalizedDegrees
        let resolvedDirection: Direction

        switch type {
        case .combined:
            if normalizedDirection > 345.0 || normalizedDirection <= 15.0 {
                resolvedDirection = .ahead
            } else if normalizedDirection <= 75.0 {
                resolvedDirection = .aheadRight
            } else if normalizedDirection <= 105.0 {
                resolvedDirection = .right
            } else if normalizedDirection <= 165.0 {
                resolvedDirection = .behindRight
            } else if normalizedDirection <= 195.0 {
                resolvedDirection = .behind
            } else if normalizedDirection <= 255.0 {
                resolvedDirection = .behindLeft
            } else if normalizedDirection <= 285.0 {
                resolvedDirection = .left
            } else {
                resolvedDirection = .aheadLeft
            }
        case .individual:
            if normalizedDirection > 315.0 || normalizedDirection <= 45.0 {
                resolvedDirection = .ahead
            } else if normalizedDirection <= 135.0 {
                resolvedDirection = .right
            } else if normalizedDirection <= 225.0 {
                resolvedDirection = .behind
            } else {
                resolvedDirection = .left
            }
        case .aheadBehind:
            if normalizedDirection > 285.0 || normalizedDirection <= 75.0 {
                resolvedDirection = .ahead
            } else if normalizedDirection <= 105.0 {
                resolvedDirection = .right
            } else if normalizedDirection <= 255.0 {
                resolvedDirection = .behind
            } else {
                resolvedDirection = .left
            }
        case .leftRight:
            if normalizedDirection > 330.0 || normalizedDirection <= 30.0 {
                resolvedDirection = .ahead
            } else if normalizedDirection <= 150.0 {
                resolvedDirection = .right
            } else if normalizedDirection <= 210.0 {
                resolvedDirection = .behind
            } else {
                resolvedDirection = .left
            }
        }

        self = resolvedDirection
    }

    func localizedString(locale: Locale) -> String {
        let key: String
        switch self {
        case .behind:
            key = "directions.direction.behind"
        case .behindLeft:
            key = "directions.direction.behind_to_the_left"
        case .left:
            key = "directions.direction.to_the_left"
        case .aheadLeft:
            key = "directions.direction.ahead_to_the_left"
        case .ahead:
            key = "directions.direction.ahead"
        case .aheadRight:
            key = "directions.direction.ahead_to_the_right"
        case .right:
            key = "directions.direction.to_the_right"
        case .behindRight:
            key = "directions.direction.behind_to_the_right"
        case .unknown:
            key = "poi.unknown"
        }

        return LanguageLocalizer.localizedString(key, locale: locale)
    }
}

extension Double {
    func bearing(to direction: Double) -> Double {
        direction.add(degrees: -self)
    }

    func add(degrees: Double) -> Double {
        fmod(self + degrees + 360.0, 360.0)
    }

    var normalizedDegrees: Double {
        add(degrees: 0)
    }
}
