// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum DistanceUnit: Sendable {
    case meters(Double)
    case kilometers(Double)
    case feet(Double)
    case miles(Double)
}

extension DistanceUnit {
    static let oneMeter = DistanceUnit.meters(1.0)
    static let oneKilometer = DistanceUnit.kilometers(1.0)
    static let oneFoot = DistanceUnit.feet(1.0)
    static let oneMile = DistanceUnit.miles(1.0)
    static let oneThousandFeet = DistanceUnit.feet(1000.0)
}

public extension DistanceUnit {
    init(meters: Double) {
        if meters < DistanceUnit.oneKilometer.asMeters.doubleValue {
            self = .meters(meters)
        } else {
            self = .kilometers(meters.metersToKilometers)
        }
    }

    init(feet: Double) {
        if feet < DistanceUnit.oneThousandFeet.doubleValue {
            self = .feet(feet)
        } else {
            self = .miles(feet.feetToMiles)
        }
    }

    func symbol(abbreviated: Bool = false) -> String {
        switch self {
        case .meters(let meters):
            return abbreviated ? "m" : (meters.roundToDecimalPlaces(2) == DistanceUnit.oneMeter.doubleValue) ? "meter" : "meters"
        case .kilometers(let kilometers):
            return abbreviated ? "km" : (kilometers.roundToDecimalPlaces(2) == DistanceUnit.oneKilometer.doubleValue) ? "kilometer" : "kilometers"
        case .feet(let feet):
            return abbreviated ? "ft" : (feet.roundToDecimalPlaces(2) == DistanceUnit.oneFoot.doubleValue) ? "foot" : "feet"
        case .miles(let miles):
            return abbreviated ? "mi" : (miles.roundToDecimalPlaces(2) == DistanceUnit.oneMile.doubleValue) ? "mile" : "miles"
        }
    }

    var isKilometers: Bool {
        if case .kilometers = self {
            return true
        }

        return false
    }

    var isMiles: Bool {
        if case .miles = self {
            return true
        }

        return false
    }

    var asImperial: DistanceUnit {
        switch self {
        case .meters, .kilometers:
            return DistanceUnit(feet: asFeet.doubleValue)
        case .feet, .miles:
            return self
        }
    }

    var asMeters: DistanceUnit {
        switch self {
        case .meters:
            return self
        case .kilometers(let kilometers):
            return .meters(kilometers.kilometersToMeters)
        case .feet(let feet):
            return .meters(feet.feetToMeters)
        case .miles(let miles):
            return .meters(miles.milesToMeters)
        }
    }

    var asKilometers: DistanceUnit {
        switch self {
        case .meters(let meters):
            return .kilometers(meters.metersToKilometers)
        case .kilometers:
            return self
        case .feet(let feet):
            return .kilometers(feet.feetToKilometers)
        case .miles(let miles):
            return .kilometers(miles.milesToKilometers)
        }
    }

    var asFeet: DistanceUnit {
        switch self {
        case .meters(let meters):
            return .feet(meters.metersToFeet)
        case .kilometers(let kilometers):
            return .feet(kilometers.kilometersToFeet)
        case .feet:
            return self
        case .miles(let miles):
            return .feet(miles.milesToFeet)
        }
    }

    var asMiles: DistanceUnit {
        switch self {
        case .meters(let meters):
            return .miles(meters.metersToMiles)
        case .kilometers(let kilometers):
            return .miles(kilometers.kilometersToMiles)
        case .feet(let feet):
            return .miles(feet.feetToMiles)
        case .miles:
            return self
        }
    }

    var doubleValue: Double {
        switch self {
        case .meters(let meters):
            return meters
        case .kilometers(let kilometers):
            return kilometers
        case .feet(let feet):
            return feet
        case .miles(let miles):
            return miles
        }
    }

    func roundToNearestMeters(_ nearestMeters: Double, canChangeUnit: Bool = false) -> DistanceUnit {
        let roundedMeters = asMeters.doubleValue.roundToNearest(nearestMeters)
        let roundedUnit = DistanceUnit.meters(roundedMeters)

        switch self {
        case .meters:
            return canChangeUnit ? DistanceUnit(meters: roundedMeters) : roundedUnit
        case .kilometers:
            return canChangeUnit ? DistanceUnit(meters: roundedMeters) : roundedUnit.asKilometers
        case .feet:
            return canChangeUnit ? DistanceUnit(feet: roundedUnit.asFeet.doubleValue) : roundedUnit.asFeet
        case .miles:
            return canChangeUnit ? DistanceUnit(feet: roundedUnit.asFeet.doubleValue) : roundedUnit.asMiles
        }
    }

    func roundToNearestFeet(_ nearestFeet: Double, canChangeUnit: Bool = false) -> DistanceUnit {
        let roundedFeet = asFeet.doubleValue.roundToNearest(nearestFeet)
        let roundedUnit = DistanceUnit.feet(roundedFeet)

        switch self {
        case .meters:
            return canChangeUnit ? DistanceUnit(meters: roundedUnit.asMeters.doubleValue) : roundedUnit.asMeters
        case .kilometers:
            return canChangeUnit ? DistanceUnit(meters: roundedUnit.asMeters.doubleValue) : roundedUnit.asKilometers
        case .feet:
            return canChangeUnit ? DistanceUnit(feet: roundedFeet) : roundedUnit
        case .miles:
            return canChangeUnit ? DistanceUnit(feet: roundedFeet) : roundedUnit.asMiles
        }
    }

    func roundToDecimalPlaces(_ toDecimalPlaces: Int) -> DistanceUnit {
        switch self {
        case .meters(let meters):
            return .meters(meters.roundToDecimalPlaces(toDecimalPlaces))
        case .kilometers(let kilometers):
            return .kilometers(kilometers.roundToDecimalPlaces(toDecimalPlaces))
        case .feet(let feet):
            return .feet(feet.roundToDecimalPlaces(toDecimalPlaces))
        case .miles(let miles):
            return .miles(miles.roundToDecimalPlaces(toDecimalPlaces))
        }
    }
}

extension Double {
    fileprivate func roundToNearest(_ toNearest: Double) -> Double {
        (self / toNearest).rounded() * toNearest
    }

    fileprivate func roundToDecimalPlaces(_ toDecimalPlaces: Int) -> Double {
        let divisor = pow(10.0, Double(toDecimalPlaces))
        return (self * divisor).rounded() / divisor
    }

    fileprivate var metersToKilometers: Double {
        convert(from: UnitLength.meters, to: UnitLength.kilometers)
    }

    fileprivate var metersToFeet: Double {
        convert(from: UnitLength.meters, to: UnitLength.feet)
    }

    fileprivate var metersToMiles: Double {
        convert(from: UnitLength.meters, to: UnitLength.miles)
    }

    fileprivate var kilometersToMeters: Double {
        convert(from: UnitLength.kilometers, to: UnitLength.meters)
    }

    fileprivate var kilometersToFeet: Double {
        convert(from: UnitLength.kilometers, to: UnitLength.feet)
    }

    fileprivate var kilometersToMiles: Double {
        convert(from: UnitLength.kilometers, to: UnitLength.miles)
    }

    fileprivate var feetToMiles: Double {
        convert(from: UnitLength.feet, to: UnitLength.miles)
    }

    fileprivate var feetToMeters: Double {
        convert(from: UnitLength.feet, to: UnitLength.meters)
    }

    fileprivate var feetToKilometers: Double {
        convert(from: UnitLength.feet, to: UnitLength.kilometers)
    }

    fileprivate var milesToFeet: Double {
        convert(from: UnitLength.miles, to: UnitLength.feet)
    }

    fileprivate var milesToMeters: Double {
        convert(from: UnitLength.miles, to: UnitLength.meters)
    }

    fileprivate var milesToKilometers: Double {
        convert(from: UnitLength.miles, to: UnitLength.kilometers)
    }

    private func convert(from: UnitLength, to: UnitLength) -> Double {
        Measurement(value: self, unit: from).converted(to: to).value
    }
}
