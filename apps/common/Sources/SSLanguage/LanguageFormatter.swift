// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public enum LanguageFormatter {
    public enum RoadNameDirection: Sendable {
        case left
        case ahead
        case right
    }

    public enum NamedLocationStreetAddressStyle: Sendable {
        case nearby
        case current(distance: String)
        case unknownDistance
    }

    public static func string(
        from distance: Double,
        accuracy: Double,
        name: String,
        options: DistanceFormatter.Options
    ) -> String {
        let formattedDistance = formattedDistance(from: distance, options: options)
        let distanceStyle = DistanceStyle(for: distance, accuracy: accuracy)
        return string(fromFormattedDistance: formattedDistance, distanceStyle: distanceStyle, name: name, locale: options.locale ?? .current)
    }

    public static func string(
        fromFormattedDistance formattedDistance: String,
        distanceStyle: DistanceStyle,
        name: String,
        locale: Locale
    ) -> String {
        let key: String
        switch distanceStyle {
        case .default:
            key = "directions.name_distance"
        case .close:
            key = "directions.name_close_by"
        case .about:
            key = "directions.name_about_distance"
        case .around:
            key = "directions.name_around_distance"
        }

        let arguments = distanceStyle == .close ? [name] : [name, formattedDistance]
        return LanguageLocalizer.localizedString(
            key,
            arguments: arguments,
            locale: locale,
            normalizeArguments: true
        )
    }

    public static func formattedDistance(
        from distance: Double,
        options: DistanceFormatter.Options
    ) -> String {
        let distanceFormatter = DistanceFormatter(options: options)
        return distanceFormatter.string(fromDistance: distance)
    }

    public static func spellOutDistance(
        _ distance: Double,
        options: DistanceFormatter.Options
    ) -> String {
        var modifiedOptions = options
        modifiedOptions.spellOut = true
        return formattedDistance(from: distance, options: modifiedOptions)
    }

    public static func encodedDirection(
        to destinationCoordinate: SSGeoCoordinate,
        type: RelativeDirectionType = .combined
    ) -> String {
        CodeableDirection(destinationCoordinate: destinationCoordinate, directionType: type).encode()
    }

    public static func encodedDirection(
        from originCoordinate: SSGeoCoordinate,
        to destinationCoordinate: SSGeoCoordinate,
        heading: Double,
        type: RelativeDirectionType = .combined
    ) -> String {
        CodeableDirection(
            originCoordinate: originCoordinate,
            originHeading: heading,
            destinationCoordinate: destinationCoordinate,
            directionType: type
        ).encode()
    }

    public static func expandCodedDirection(
        for string: String,
        coordinate: SSGeoCoordinate?,
        heading: Double?,
        locale: Locale
    ) -> String {
        let codedDirection: CodeableDirection.Result

        do {
            codedDirection = try CodeableDirection.decode(
                string: string,
                originCoordinate: coordinate,
                originHeading: heading
            )
        } catch CodeableDirection.DecodingError.invalidOrigin(let result) {
            codedDirection = result
        } catch {
            return string
        }

        let direction = codedDirection.direction
        let directionString = direction == .unknown
            ? LanguageLocalizer.localizedString("directions.direction.away", locale: locale)
            : direction.localizedString(locale: locale)

        return string.replacingOccurrences(of: codedDirection.encodedSubstring, with: directionString)
    }

    public static func roadNameString(
        name: String,
        direction: RoadNameDirection,
        roundabout: Bool = false,
        locale: Locale
    ) -> String {
        let key: String

        switch (direction, roundabout) {
        case (.left, false):
            key = "directions.name_goes_left"
        case (.left, true):
            key = "directions.name_goes_left.roundabout"
        case (.ahead, false):
            key = "directions.name_continues_ahead"
        case (.ahead, true):
            key = "directions.name_continues_ahead.roundabout"
        case (.right, false):
            key = "directions.name_goes_right"
        case (.right, true):
            key = "directions.name_goes_right.roundabout"
        }

        return LanguageLocalizer.localizedString(
            key,
            arguments: [name],
            locale: locale,
            normalizeArguments: true
        )
    }

    public static func roundaboutNameString(
        name: String,
        includesRoundaboutInName: Bool,
        locale: Locale
    ) -> String {
        guard !includesRoundaboutInName else {
            return name
        }

        return LanguageLocalizer.localizedString(
            "directions.name_roundabout",
            arguments: [name],
            locale: locale,
            normalizeArguments: true
        )
    }

    public static func approachingRoundaboutString(
        name: String,
        includesRoundaboutInName: Bool,
        exitCount: Int? = nil,
        locale: Locale
    ) -> String {
        let key: String
        let arguments: [String]

        if let exitCount {
            arguments = [name, String(exitCount)]
            key = includesRoundaboutInName
                ? "directions.approaching_name_with_exits"
                : "directions.approaching_name_roundabout_with_exits"
        } else {
            arguments = [name]
            key = includesRoundaboutInName
                ? "directions.approaching_name"
                : "directions.approaching_name_roundabout"
        }

        return LanguageLocalizer.localizedString(
            key,
            arguments: arguments,
            locale: locale,
            normalizeArguments: true
        )
    }

    public static func namedLocationStreetAddressString(
        name: String,
        address: String,
        style: NamedLocationStreetAddressStyle,
        locale: Locale
    ) -> String {
        let key: String
        let arguments: [String]

        switch style {
        case .nearby:
            key = "directions.name_is_nearby_street_address"
            arguments = [name, address]
        case .current(let distance):
            key = "directions.name_is_currently_street_address"
            arguments = [name, distance, address]
        case .unknownDistance:
            key = "directions.name_street_address"
            arguments = [name, address]
        }

        return LanguageLocalizer.localizedString(
            key,
            arguments: arguments,
            locale: locale,
            normalizeArguments: true
        )
    }
}

public extension LanguageFormatter {
    enum DistanceStyle: String, Sendable {
        case `default`
        case close
        case about
        case around

        private static let closeByDistance = 15.0
        private static let farAwayDistance = 200.0
        private static let goodAccuracy = 10.0
        private static let averageAccuracy = 20.0

        init(for distance: Double, accuracy: Double) {
            let distanceUnit = DistanceUnit.meters(distance)
            let rounded = DistanceFormatter.rounded(distanceUnit: distanceUnit, canChangeUnit: false)

            if rounded.doubleValue <= DistanceStyle.closeByDistance {
                self = .close
            } else if distance >= DistanceStyle.farAwayDistance {
                self = .default
            } else if accuracy <= DistanceStyle.goodAccuracy {
                self = .default
            } else if accuracy <= DistanceStyle.averageAccuracy {
                self = .about
            } else {
                self = .around
            }
        }
    }
}
