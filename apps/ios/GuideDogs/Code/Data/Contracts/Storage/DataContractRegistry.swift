//
//  DataContractRegistry.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation

@MainActor
private struct DataContractDefaults {
    let spatialRead: SpatialReadContract
    let spatialWrite: SpatialWriteContract
    let spatialMaintenanceWrite: SpatialMaintenanceWriteContract
}

@MainActor
enum DataContractRegistry {
    private static var installedDefaults: DataContractDefaults?
    private static var configuredContracts: DataContractDefaults?

    static var spatialRead: SpatialReadContract {
        activeContracts.spatialRead
    }

    static var spatialWrite: SpatialWriteContract {
        activeContracts.spatialWrite
    }

    static var spatialMaintenanceWrite: SpatialMaintenanceWriteContract {
        activeContracts.spatialMaintenanceWrite
    }

    static func installDefaults(
        spatialRead: SpatialReadContract,
        spatialWrite: SpatialWriteContract,
        spatialMaintenanceWrite: SpatialMaintenanceWriteContract
    ) {
        let defaults = DataContractDefaults(spatialRead: spatialRead,
                                            spatialWrite: spatialWrite,
                                            spatialMaintenanceWrite: spatialMaintenanceWrite)
        installedDefaults = defaults
        configuredContracts = nil
    }

    static func configure(
        spatialRead: SpatialReadContract,
        spatialWrite: SpatialWriteContract? = nil,
        spatialMaintenanceWrite: SpatialMaintenanceWriteContract? = nil
    ) {
        let defaults = requireInstalledDefaults()
        configuredContracts = DataContractDefaults(spatialRead: spatialRead,
                                                   spatialWrite: spatialWrite ?? defaults.spatialWrite,
                                                   spatialMaintenanceWrite: spatialMaintenanceWrite ?? defaults.spatialMaintenanceWrite)
    }

    static func resetForTesting() {
        configuredContracts = nil
    }

    private static var activeContracts: DataContractDefaults {
        configuredContracts ?? requireInstalledDefaults()
    }

    private static func requireInstalledDefaults() -> DataContractDefaults {
        guard let installedDefaults else {
            preconditionFailure("DataContractRegistry defaults were used before installation")
        }

        return installedDefaults
    }
}
