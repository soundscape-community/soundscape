//
//  RealmSpatialWriteContract.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation

@MainActor
struct RealmSpatialWriteContract: SpatialWriteContract, SpatialWriteCompatibilityContract {
    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) throws -> String {
        try SpatialDataStoreRegistry.store.addReferenceEntity(detail: detail,
                                                              telemetryContext: telemetryContext,
                                                              notify: notify)
    }

    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) async throws -> String {
        try (self as SpatialWriteCompatibilityContract).addReferenceEntity(detail: detail,
                                                                           telemetryContext: telemetryContext,
                                                                           notify: notify)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String {
        try (self as SpatialWriteCompatibilityContract).addTemporaryReferenceEntity(location: location,
                                                                                    estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location,
                                                                       nickname: nickname,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String {
        try (self as SpatialWriteCompatibilityContract).addTemporaryReferenceEntity(location: location,
                                                                                    nickname: nickname,
                                                                                    estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(entityKey: entityKey,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String {
        try (self as SpatialWriteCompatibilityContract).addTemporaryReferenceEntity(entityKey: entityKey,
                                                                                    estimatedAddress: estimatedAddress)
    }

    func removeReferenceEntity(id: String) throws {
        try RealmReferenceEntity.remove(id: id)
    }

    func removeReferenceEntity(id: String) async throws {
        try (self as SpatialWriteCompatibilityContract).removeReferenceEntity(id: id)
    }

    func removeAllTemporaryReferenceEntities() throws {
        try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
    }

    func removeAllTemporaryReferenceEntities() async throws {
        try (self as SpatialWriteCompatibilityContract).removeAllTemporaryReferenceEntities()
    }
}
