//
//  LanguageFormatter.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSLanguage

@MainActor
enum LanguageFormatter {
    typealias DistanceStyle = SSLanguage.LanguageFormatter.DistanceStyle
    typealias RoadNameDirection = SSLanguage.LanguageFormatter.RoadNameDirection
    typealias NamedLocationStreetAddressStyle = SSLanguage.LanguageFormatter.NamedLocationStreetAddressStyle
    typealias CardinalMovementStyle = SSLanguage.LanguageFormatter.CardinalMovementStyle

    private static var defaultOptions: DistanceFormatter.Options {
        DistanceFormatter.Options(
            metric: SettingsContext.shared.metricUnits,
            rounding: false,
            spellOut: false,
            locale: LocalizationContext.currentAppLocale,
            abbreviated: false
        )
    }

    static func string(from distance: CLLocationDistance, accuracy: Double, name: String) -> String {
        string(from: distance, with: name, accuracy: accuracy)
    }

    static func string(
        from distance: CLLocationDistance,
        with name: String,
        rounding: Bool = true,
        accuracy: CLLocationAccuracy
    ) -> String {
        var options = defaultOptions
        options.rounding = rounding
        return string(from: distance, with: name, accuracy: accuracy, options: options)
    }

    static func string(
        from distance: CLLocationDistance,
        with name: String,
        accuracy: CLLocationAccuracy,
        options: DistanceFormatter.Options
    ) -> String {
        SSLanguage.LanguageFormatter.string(
            from: distance,
            accuracy: accuracy,
            name: name,
            options: options
        )
    }

    static func string(
        fromFormattedDistance formattedDistance: String,
        distanceStyle: DistanceStyle,
        name: String
    ) -> String {
        SSLanguage.LanguageFormatter.string(
            fromFormattedDistance: formattedDistance,
            distanceStyle: distanceStyle,
            name: name,
            locale: LocalizationContext.currentAppLocale
        )
    }

    static func string(
        from distance: CLLocationDistance,
        rounded: Bool? = nil,
        spellOut: Bool? = nil,
        abbreviated: Bool? = nil
    ) -> String {
        var options = defaultOptions

        if let rounded {
            options.rounding = rounded
        }

        if let spellOut {
            options.spellOut = spellOut
        }

        if let abbreviated {
            options.abbreviated = abbreviated
        }

        return formattedDistance(from: distance, options: options)
    }

    static func spellOutDistance(_ distance: CLLocationDistance) -> String {
        var options = defaultOptions
        options.spellOut = true
        return formattedDistance(from: distance, options: options)
    }

    static func formattedDistance(from distance: CLLocationDistance) -> String {
        formattedDistance(from: distance, options: defaultOptions)
    }

    static func formattedDistance(from distance: CLLocationDistance, options: DistanceFormatter.Options) -> String {
        SSLanguage.LanguageFormatter.formattedDistance(from: distance, options: options)
    }

    static func encodedDirection(toLocation: CLLocation, type: RelativeDirectionType = .combined) -> String {
        SSLanguage.LanguageFormatter.encodedDirection(
            to: toLocation.coordinate.ssGeoCoordinate,
            type: type
        )
    }

    static func encodedDirection(
        fromLocation: CLLocation,
        toLocation: CLLocation,
        heading: CLLocationDirection,
        type: RelativeDirectionType = .combined
    ) -> String {
        SSLanguage.LanguageFormatter.encodedDirection(
            from: fromLocation.coordinate.ssGeoCoordinate,
            to: toLocation.coordinate.ssGeoCoordinate,
            heading: heading,
            type: type
        )
    }

    static func expandCodedDirection(for string: String) -> String {
        expandCodedDirection(
            for: string,
            coordinate: AppContext.shared.geolocationManager.location?.coordinate,
            heading: AppContext.shared.geolocationManager.collectionHeading.value ?? Heading.defaultValue
        )
    }

    static func expandCodedDirection(
        for string: String,
        coordinate: CLLocationCoordinate2D?,
        heading: CLLocationDirection?
    ) -> String {
        SSLanguage.LanguageFormatter.expandCodedDirection(
            for: string,
            coordinate: coordinate?.ssGeoCoordinate,
            heading: heading,
            locale: LocalizationContext.currentAppLocale
        )
    }

    static func roadNameString(
        name: String,
        direction: RoadNameDirection,
        roundabout: Bool = false
    ) -> String {
        SSLanguage.LanguageFormatter.roadNameString(
            name: name,
            direction: direction,
            roundabout: roundabout,
            locale: LocalizationContext.currentAppLocale
        )
    }

    static func roundaboutNameString(
        name: String,
        includesRoundaboutInName: Bool
    ) -> String {
        SSLanguage.LanguageFormatter.roundaboutNameString(
            name: name,
            includesRoundaboutInName: includesRoundaboutInName,
            locale: LocalizationContext.currentAppLocale
        )
    }

    static func approachingRoundaboutString(
        name: String,
        includesRoundaboutInName: Bool,
        exitCount: Int? = nil
    ) -> String {
        SSLanguage.LanguageFormatter.approachingRoundaboutString(
            name: name,
            includesRoundaboutInName: includesRoundaboutInName,
            exitCount: exitCount,
            locale: LocalizationContext.currentAppLocale
        )
    }

    static func namedLocationStreetAddressString(
        name: String,
        address: String,
        style: NamedLocationStreetAddressStyle
    ) -> String {
        SSLanguage.LanguageFormatter.namedLocationStreetAddressString(
            name: name,
            address: address,
            style: style,
            locale: LocalizationContext.currentAppLocale
        )
    }

    static func cardinalMovementString(
        direction: CardinalDirection,
        style: CardinalMovementStyle,
        roadName: String? = nil
    ) -> String {
        SSLanguage.LanguageFormatter.cardinalMovementString(
            direction: direction,
            style: style,
            roadName: roadName,
            locale: LocalizationContext.currentAppLocale
        )
    }
}
