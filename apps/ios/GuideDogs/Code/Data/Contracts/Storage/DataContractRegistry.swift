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
    private static let defaultSpatialWriteAdapter = RealmSpatialWriteContract()
    private(set) static var spatialRead: SpatialReadContract = defaultSpatialRead
    private(set) static var spatialWrite: SpatialWriteContract = defaultSpatialWriteAdapter
    private(set) static var spatialMaintenanceWrite: SpatialMaintenanceWriteContract = defaultSpatialWriteAdapter

    static func configure(
        spatialRead: SpatialReadContract,
        spatialWrite: SpatialWriteContract? = nil,
        spatialMaintenanceWrite: SpatialMaintenanceWriteContract? = nil
    ) {
        self.spatialRead = spatialRead

        if let spatialWrite {
            self.spatialWrite = spatialWrite
        } else {
            self.spatialWrite = defaultSpatialWriteAdapter
        }

        if let spatialMaintenanceWrite {
            self.spatialMaintenanceWrite = spatialMaintenanceWrite
        } else {
            self.spatialMaintenanceWrite = defaultSpatialWriteAdapter
        }
    }

    static func resetForTesting() {
        spatialRead = defaultSpatialRead
        spatialWrite = defaultSpatialWriteAdapter
        spatialMaintenanceWrite = defaultSpatialWriteAdapter
    }
}
