//
//  RealmSpatialWriteContract.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSGeo

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

    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?) throws -> String {
        try RealmReferenceEntity.add(entityKey: entityKey,
                                     nickname: nickname,
                                     estimatedAddress: estimatedAddress,
                                     annotation: annotation,
                                     context: context)
    }

    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?) async throws -> String {
        try (self as SpatialWriteCompatibilityContract).addReferenceEntity(entityKey: entityKey,
                                                                           nickname: nickname,
                                                                           estimatedAddress: estimatedAddress,
                                                                           annotation: annotation,
                                                                           context: context)
    }

    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?, temporary: Bool, context: String?) throws -> String {
        try RealmReferenceEntity.add(location: location,
                                     nickname: nickname,
                                     estimatedAddress: estimatedAddress,
                                     annotation: annotation,
                                     temporary: temporary,
                                     context: context)
    }

    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?, temporary: Bool, context: String?) async throws -> String {
        try (self as SpatialWriteCompatibilityContract).addReferenceEntity(location: location,
                                                                           nickname: nickname,
                                                                           estimatedAddress: estimatedAddress,
                                                                           annotation: annotation,
                                                                           temporary: temporary,
                                                                           context: context)
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

    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?, isTemp: Bool) throws {
        guard let entity = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return
        }

        try RealmReferenceEntity.update(entity: entity,
                                        location: location?.clCoordinate,
                                        nickname: nickname,
                                        address: estimatedAddress,
                                        annotation: annotation,
                                        context: context,
                                        isTemp: isTemp)
    }

    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?, isTemp: Bool) async throws {
        try (self as SpatialWriteCompatibilityContract).updateReferenceEntity(id: id,
                                                                              location: location,
                                                                              nickname: nickname,
                                                                              estimatedAddress: estimatedAddress,
                                                                              annotation: annotation,
                                                                              context: context,
                                                                              isTemp: isTemp)
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
