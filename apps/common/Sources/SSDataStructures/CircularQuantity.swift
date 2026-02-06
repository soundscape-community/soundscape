//
//  CircularQuantity.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

public struct CircularQuantity {

    // MARK: Properties
    
    public let valueInDegrees: Double
    public let valueInRadians: Double

    private static let degreesToRadiansFactor = Double.pi / 180.0
    private static let radiansToDegreesFactor = 180.0 / Double.pi
    
    // MARK: Initialization
    
    public init(valueInDegrees: Double) {
        self.valueInDegrees = valueInDegrees
        self.valueInRadians = valueInDegrees * Self.degreesToRadiansFactor
    }
    
    public init(valueInRadians: Double) {
        self.valueInDegrees = valueInRadians * Self.radiansToDegreesFactor
        self.valueInRadians = valueInRadians
    }
    
    // MARK: -
    
    public func normalized() -> CircularQuantity {
        var constant = 1.0
        
        if abs(valueInDegrees) > 360.0 {
            constant = ceil(abs(valueInDegrees) / 360.0)
        }
        
        let nValueInDegrees = fmod(valueInDegrees + (constant * 360.0), 360.0)
        return CircularQuantity(valueInDegrees: nValueInDegrees)
    }
    
}

extension CircularQuantity: Comparable {
    
    public static func == (lhs: CircularQuantity, rhs: CircularQuantity) -> Bool {
        return lhs.normalized().valueInDegrees == rhs.normalized().valueInDegrees
    }
    
    public static func > (lhs: CircularQuantity, rhs: CircularQuantity) -> Bool {
        return lhs.normalized().valueInDegrees > rhs.normalized().valueInDegrees
    }
    
    public static func < (lhs: CircularQuantity, rhs: CircularQuantity) -> Bool {
        return lhs.normalized().valueInDegrees < rhs.normalized().valueInDegrees
    }
    
    public static func + (lhs: CircularQuantity, rhs: CircularQuantity) -> CircularQuantity {
        let sum = lhs.normalized().valueInDegrees + rhs.normalized().valueInDegrees
        return CircularQuantity(valueInDegrees: sum).normalized()
    }
    
    public static func - (lhs: CircularQuantity, rhs: CircularQuantity) -> CircularQuantity {
        let difference = lhs.normalized().valueInDegrees - rhs.normalized().valueInDegrees
        return CircularQuantity(valueInDegrees: difference).normalized()
    }
    
    public prefix static func - (value: CircularQuantity) -> CircularQuantity {
        let valueInDegrees = value.valueInDegrees
        return CircularQuantity(valueInDegrees: -valueInDegrees).normalized()
    }
    
}

extension CircularQuantity: CustomStringConvertible {
    
    public var description: String {
        return "\(valueInDegrees)"
    }
    
}
