//
//  RealmSpatialWriteContract.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSGeo

@MainActor
struct RealmSpatialWriteContract: SpatialWriteContract {
    func addRoute(_ route: Route) async throws {
        try Route.add(route)
    }

    func importRouteFromCloud(_ route: Route) async throws {
        try Route.importFromCloud(route)
    }

    func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws {
        try RealmReferenceEntity.importFromCloud(markerParameters: markerParameters, entity: entity)
    }

    func deleteRoute(id: String) async throws {
        try Route.delete(id)
    }

    func updateRoute(_ route: Route) async throws {
        try Route.update(id: route.id,
                         name: route.name,
                         description: route.routeDescription,
                         waypoints: route.waypoints.asLocationDetail)
    }

    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) async throws -> String {
        try SpatialDataStoreRegistry.store.addReferenceEntity(detail: detail,
                                                              telemetryContext: telemetryContext,
                                                              notify: notify)
    }

    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?) async throws -> String {
        try RealmReferenceEntity.add(entityKey: entityKey,
                                     nickname: nickname,
                                     estimatedAddress: estimatedAddress,
                                     annotation: annotation,
                                     context: context)
    }

    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?, temporary: Bool, context: String?) async throws -> String {
        try RealmReferenceEntity.add(location: location,
                                     nickname: nickname,
                                     estimatedAddress: estimatedAddress,
                                     annotation: annotation,
                                     temporary: temporary,
                                     context: context)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location,
                                                                       nickname: nickname,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(entityKey: entityKey,
                                                                       estimatedAddress: estimatedAddress)
    }

    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?, isTemp: Bool) async throws {
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

    func removeAllReferenceEntities() async throws {
        try RealmReferenceEntity.removeAll()
    }

    func removeAllRoutes() async throws {
        try Route.deleteAll()
    }

    func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws {
        guard let cache = try? RealmHelper.getCacheRealm() else {
            throw RouteRealmError.databaseError
        }

        try cache.write {
            for record in addresses {
                let address = Address()
                address.key = record.key
                address.lastSelectedDate = record.lastSelectedDate
                address.name = record.name
                address.addressLine = record.addressLine
                address.streetName = record.streetName
                address.latitude = record.latitude
                address.longitude = record.longitude
                address.centroidLatitude = record.centroidLatitude
                address.centroidLongitude = record.centroidLongitude
                address.searchString = record.searchString
                cache.create(Address.self, value: address, update: .modified)
            }
        }
    }

    func cleanCorruptReferenceEntities() async throws {
        try RealmReferenceEntity.cleanCorruptEntities()
    }

    func removeReferenceEntity(id: String) async throws {
        try RealmReferenceEntity.remove(id: id)
    }

    func removeAllTemporaryReferenceEntities() async throws {
        try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
    }
}

@MainActor
struct SpatialDataDestinationEntityStore: DestinationEntityStore {
    func referenceEntity(forReferenceID id: String) -> RealmReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByKey(id)
    }

    func referenceEntityID(forGenericLocation location: GenericLocation) -> String? {
        SpatialDataStoreRegistry.store.referenceEntityByLocation(location.location.coordinate)?.id
    }

    func referenceEntityID(forEntityKey key: String) -> String? {
        SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key)?.id
    }

    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location,
                                                                       nickname: nickname,
                                                                       estimatedAddress: estimatedAddress)
    }

    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String {
        try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(entityKey: entityKey,
                                                                       estimatedAddress: estimatedAddress)
    }

    func removeAllTemporaryReferenceEntities() throws {
        try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
    }
}
