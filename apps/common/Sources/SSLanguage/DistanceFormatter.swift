// Copyright (c) Soundscape Community Contributers.

import Foundation

public final class DistanceFormatter {
    public struct Options: Sendable {
        public static let `default` = Options()

        public var metric: Bool
        public var rounding: Bool
        public var spellOut: Bool
        public var locale: Locale?
        public var abbreviated: Bool

        public init(
            metric: Bool = true,
            rounding: Bool = false,
            spellOut: Bool = false,
            locale: Locale? = nil,
            abbreviated: Bool = false
        ) {
            self.metric = metric
            self.rounding = rounding
            self.spellOut = spellOut
            self.locale = locale
            self.abbreviated = abbreviated
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static let spellOutNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        formatter.numberStyle = .spellOut
        return formatter
    }()

    public var options: Options

    public convenience init() {
        self.init(options: .default)
    }

    public init(options: Options) {
        self.options = options
    }

    public func string(fromDistance distance: Double) -> String {
        let distanceUnit = DistanceFormatter.formattedDistanceUnit(
            for: distance,
            asMetric: options.metric,
            rounded: options.rounding
        )

        let number = DistanceFormatter.formattedNumber(
            distance: distanceUnit.doubleValue,
            spellOut: options.spellOut,
            locale: options.locale
        )

        let unit = distanceUnit.symbol(abbreviated: options.abbreviated)
        return LanguageLocalizer.localizedString(
            "distance.format.\(unit)",
            arguments: [number],
            locale: options.locale ?? .current,
            normalizeArguments: true
        )
    }

    private static func formattedDistanceUnit(
        for distance: Double,
        asMetric: Bool = true,
        rounded: Bool = true
    ) -> DistanceUnit {
        let metricDistanceUnit = DistanceUnit(meters: distance)
        let distanceUnit = asMetric ? metricDistanceUnit : metricDistanceUnit.asImperial

        if rounded {
            return DistanceFormatter.rounded(
                distanceUnit: distanceUnit,
                canChangeUnit: true,
                roundToNaturalDistance: true
            )
        }

        return distanceUnit
    }

    public static func rounded(
        distanceUnit: DistanceUnit,
        canChangeUnit: Bool,
        roundToNaturalDistance: Bool = false
    ) -> DistanceUnit {
        if roundToNaturalDistance {
            switch distanceUnit {
            case .meters:
                return distanceUnit.roundToNearestMeters(5, canChangeUnit: canChangeUnit)
            case .kilometers:
                return distanceUnit.roundToNearestMeters(50, canChangeUnit: canChangeUnit)
            case .feet(let feet):
                return distanceUnit.roundToNearestFeet(feet > 1000.0 ? 50 : 5, canChangeUnit: canChangeUnit)
            case .miles:
                return distanceUnit.roundToNearestFeet(50, canChangeUnit: canChangeUnit)
            }
        } else if (distanceUnit.isKilometers || distanceUnit.isMiles) && distanceUnit.doubleValue > 10.0 {
            return distanceUnit.roundToDecimalPlaces(1)
        } else {
            switch distanceUnit {
            case .meters, .kilometers:
                return distanceUnit.roundToNearestMeters(1, canChangeUnit: canChangeUnit)
            case .feet, .miles:
                return distanceUnit.roundToNearestFeet(1, canChangeUnit: canChangeUnit)
            }
        }
    }

    private static func formattedNumber(
        distance: Double,
        spellOut: Bool = false,
        locale: Locale? = nil
    ) -> String {
        guard var numberString = DistanceFormatter.numberFormatter.string(from: NSNumber(value: distance)) else {
            return ""
        }

        if spellOut, let number = DistanceFormatter.numberFormatter.number(from: numberString) {
            if let locale, DistanceFormatter.spellOutNumberFormatter.locale != locale {
                DistanceFormatter.spellOutNumberFormatter.locale = locale
            }

            numberString = DistanceFormatter.spellOutNumberFormatter.string(from: number) ?? ""
        }

        return numberString
    }
}
