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
    private static let defaultSpatialWrite = RealmSpatialWriteContract()
    private(set) static var spatialRead: SpatialReadContract = defaultSpatialRead
    private(set) static var spatialWrite: SpatialWriteContract = defaultSpatialWrite

    static func configure(
        spatialRead: SpatialReadContract,
        spatialWrite: SpatialWriteContract? = nil
    ) {
        self.spatialRead = spatialRead

        if let spatialWrite {
            self.spatialWrite = spatialWrite
        } else {
            self.spatialWrite = defaultSpatialWrite
        }
    }

    static func resetForTesting() {
        spatialRead = defaultSpatialRead
        spatialWrite = defaultSpatialWrite
    }
}
