//
//  DistanceUnit.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation

extension Double {
    internal func roundToNearest(_ toNearest: Double) -> Double {
        (self / toNearest).rounded() * toNearest
    }

    internal func roundToDecimalPlaces(_ toDecimalPlaces: Int) -> Double {
        let divisor = pow(10.0, Double(toDecimalPlaces))
        return (self * divisor).rounded() / divisor
    }
}

extension Float {
    internal func roundToNearest(_ toNearest: Float) -> Float {
        (self / toNearest).rounded() * toNearest
    }

    internal func roundToDecimalPlaces(_ toDecimalPlaces: Int) -> Float {
        let divisor = pow(10.0, Float(toDecimalPlaces))
        return (self * divisor).rounded() / divisor
    }
}
