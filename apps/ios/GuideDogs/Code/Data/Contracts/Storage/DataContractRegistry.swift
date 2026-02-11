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
    private static let defaultSpatialMaintenanceWrite = RealmSpatialWriteContract()
    private(set) static var spatialRead: SpatialReadContract = defaultSpatialRead
    private(set) static var spatialWrite: SpatialWriteContract = defaultSpatialWrite
    private(set) static var spatialMaintenanceWrite: SpatialMaintenanceWriteContract = defaultSpatialMaintenanceWrite

    static func configure(
        spatialRead: SpatialReadContract,
        spatialWrite: SpatialWriteContract? = nil,
        spatialMaintenanceWrite: SpatialMaintenanceWriteContract? = nil
    ) {
        self.spatialRead = spatialRead

        if let spatialWrite {
            self.spatialWrite = spatialWrite
        } else {
            self.spatialWrite = defaultSpatialWrite
        }

        if let spatialMaintenanceWrite {
            self.spatialMaintenanceWrite = spatialMaintenanceWrite
        } else {
            self.spatialMaintenanceWrite = defaultSpatialMaintenanceWrite
        }
    }

    static func resetForTesting() {
        spatialRead = defaultSpatialRead
        spatialWrite = defaultSpatialWrite
        spatialMaintenanceWrite = defaultSpatialMaintenanceWrite
    }
}
