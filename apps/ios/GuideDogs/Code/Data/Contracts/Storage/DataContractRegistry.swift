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
    private static let defaultSpatialWrite = RealmSpatialWriteContract()
    private static let defaultSpatialWriteCompatibility = RealmSpatialWriteContract()
    private(set) static var spatialRead: SpatialReadContract = defaultSpatialRead
    @available(*, deprecated, message: "Temporary compatibility seam. Prefer DataContractRegistry.spatialRead async APIs.")
    private(set) static var spatialReadCompatibility: SpatialReadCompatibilityContract = defaultSpatialReadCompatibility
    private(set) static var spatialWrite: SpatialWriteContract = defaultSpatialWrite
    @available(*, deprecated, message: "Temporary compatibility seam. Prefer DataContractRegistry.spatialWrite async APIs.")
    private(set) static var spatialWriteCompatibility: SpatialWriteCompatibilityContract = defaultSpatialWriteCompatibility

    static func configure(
        spatialRead: SpatialReadContract,
        spatialReadCompatibility: SpatialReadCompatibilityContract? = nil,
        spatialWrite: SpatialWriteContract? = nil,
        spatialWriteCompatibility: SpatialWriteCompatibilityContract? = nil
    ) {
        self.spatialRead = spatialRead
        if let spatialReadCompatibility {
            self.spatialReadCompatibility = spatialReadCompatibility
        } else if let inferredCompatibility = spatialRead as? SpatialReadCompatibilityContract {
            self.spatialReadCompatibility = inferredCompatibility
        } else {
            self.spatialReadCompatibility = defaultSpatialReadCompatibility
        }

        if let spatialWrite {
            self.spatialWrite = spatialWrite
        } else {
            self.spatialWrite = defaultSpatialWrite
        }

        if let spatialWriteCompatibility {
            self.spatialWriteCompatibility = spatialWriteCompatibility
        } else if let inferredWriteCompatibility = self.spatialWrite as? SpatialWriteCompatibilityContract {
            self.spatialWriteCompatibility = inferredWriteCompatibility
        } else {
            self.spatialWriteCompatibility = defaultSpatialWriteCompatibility
        }
    }

    static func resetForTesting() {
        spatialRead = defaultSpatialRead
        spatialReadCompatibility = defaultSpatialReadCompatibility
        spatialWrite = defaultSpatialWrite
        spatialWriteCompatibility = defaultSpatialWriteCompatibility
    }
}
