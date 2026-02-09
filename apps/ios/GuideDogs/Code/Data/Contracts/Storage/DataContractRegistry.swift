//
//  DataContractRegistry.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation

@MainActor
enum DataContractRegistry {
    private static let defaultSpatialRead = RealmSpatialReadContract()
    private static let defaultSpatialReadCompatibility = RealmSpatialReadContract()
    private(set) static var spatialRead: SpatialReadContract = defaultSpatialRead
    private(set) static var spatialReadCompatibility: SpatialReadCompatibilityContract = defaultSpatialReadCompatibility

    static func configure(
        spatialRead: SpatialReadContract,
        spatialReadCompatibility: SpatialReadCompatibilityContract? = nil
    ) {
        self.spatialRead = spatialRead
        if let spatialReadCompatibility {
            self.spatialReadCompatibility = spatialReadCompatibility
        } else if let inferredCompatibility = spatialRead as? SpatialReadCompatibilityContract {
            self.spatialReadCompatibility = inferredCompatibility
        } else {
            self.spatialReadCompatibility = defaultSpatialReadCompatibility
        }
    }

    static func resetForTesting() {
        spatialRead = defaultSpatialRead
        spatialReadCompatibility = defaultSpatialReadCompatibility
    }
}
