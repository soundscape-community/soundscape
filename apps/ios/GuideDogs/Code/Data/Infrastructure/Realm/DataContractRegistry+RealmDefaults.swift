//
//  DataContractRegistry+RealmDefaults.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation

@MainActor
extension DataContractRegistry {
    static func configureWithRealmDefaults() {
        installDefaults(spatialRead: RealmSpatialReadContract(),
                        spatialWrite: RealmSpatialWriteContract(),
                        spatialMaintenanceWrite: RealmSpatialMaintenanceWriteContract())
    }
}
