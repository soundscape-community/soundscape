//
//  RealmSpatialWriteContract.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import CoreLocation
import SSGeo

@MainActor
struct RealmSpatialWriteContract: SpatialWriteContract {
    func addRoute(_ route: Route) async throws {
        let spatialRead = DataContractRegistry.spatialRead
        let firstWaypointCoordinate = await resolveFirstWaypointCoordinate(for: route, using: spatialRead)
        try await Route.add(route,
                            firstWaypointCoordinate: firstWaypointCoordinate,
                            using: spatialRead)
    }

    func deleteRoute(id: String) async throws {
        try Route.delete(id)
    }

    func updateRoute(_ route: Route) async throws {
        let spatialRead = DataContractRegistry.spatialRead
        let firstWaypointCoordinate = await resolveFirstWaypointCoordinate(for: route,
                                                                           using: spatialRead)
        let waypointDetails = await route.waypoints.locationDetails(using: spatialRead)
        try Route.update(id: route.id,
                         name: route.name,
                         description: route.routeDescription,
                         waypoints: waypointDetails,
                         firstWaypointCoordinate: firstWaypointCoordinate)
    }

    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
        try await RealmReferenceEntity.add(entityKey: entityKey,
                                           nickname: nickname,
                                           estimatedAddress: estimatedAddress,
                                           annotation: annotation,
                                           context: nil,
                                           using: DataContractRegistry.spatialRead)
    }

    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
        try await RealmReferenceEntity.add(location: location,
                                           nickname: nickname,
                                           estimatedAddress: estimatedAddress,
                                           annotation: annotation,
                                           temporary: false,
                                           context: nil,
                                           using: DataContractRegistry.spatialRead)
    }

    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws {
        guard let entity = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return
        }

        try await RealmReferenceEntity.update(entity: entity,
                                              location: location?.clCoordinate,
                                              nickname: nickname,
                                              address: estimatedAddress,
                                              annotation: annotation,
                                              context: nil,
                                              isTemp: false,
                                              using: DataContractRegistry.spatialRead)
    }

    func removeReferenceEntity(id: String) async throws {
        try await RealmReferenceEntity.remove(id: id, using: DataContractRegistry.spatialRead)
    }

    private func resolveFirstWaypointCoordinate(for route: Route,
                                                using spatialRead: ReferenceReadContract) async -> CLLocationCoordinate2D? {
        await Route.firstWaypointCoordinate(for: route.waypoints, using: spatialRead)
    }
}

@MainActor
struct RealmSpatialMaintenanceWriteContract: SpatialMaintenanceWriteContract {
    func importRouteFromCloud(_ route: Route) async throws {
        let firstWaypointCoordinate = await resolveFirstWaypointCoordinate(for: route,
                                                                           using: DataContractRegistry.spatialRead)
        try Route.importFromCloud(route, firstWaypointCoordinate: firstWaypointCoordinate)
    }

    func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws {
        try await RealmReferenceEntity.importFromCloud(markerParameters: markerParameters,
                                                       entity: entity,
                                                       using: DataContractRegistry.spatialRead)
    }

    func removeAllReferenceEntities() async throws {
        // Clear the destination before deleting markers to preserve existing cache-reset behavior.
        try await ReferenceEntityRuntime.clearDestinationForCacheReset()

        let database = try RealmHelper.getDatabaseRealm()

        // Route cleanup is handled separately by callers that invoke `removeAllRoutes`.
        for entity in database.objects(RealmReferenceEntity.self) {
            let id = entity.id

            ReferenceEntityRuntime.removeReferenceFromCloud(entity.domainEntity)

            try database.write {
                database.delete(entity)

                GDATelemetry.track("markers.removed")
                GDATelemetry.helper?.markerCountRemoved += 1

                NotificationCenter.default.post(name: .markerRemoved,
                                                object: RealmReferenceEntity.self,
                                                userInfo: [ReferenceEntity.Keys.entityId: id])
            }
        }
    }

    func removeAllRoutes() async throws {
        try Route.deleteAll()
    }

    func clearNewReferenceEntitiesAndRoutes() async throws {
        try SpatialDataStoreRegistry.store.clearNewReferenceEntities()
        try SpatialDataStoreRegistry.store.clearNewRoutes()
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
        try await RealmReferenceEntity.cleanCorruptEntities(using: DataContractRegistry.spatialRead)
    }

    private func resolveFirstWaypointCoordinate(for route: Route,
                                                using spatialRead: ReferenceReadContract) async -> CLLocationCoordinate2D? {
        await Route.firstWaypointCoordinate(for: route.waypoints, using: spatialRead)
    }
}

@MainActor
struct SpatialDataDestinationEntityStore: DestinationEntityStore {
    func destinationPOI(forReferenceID id: String) -> POI? {
        SpatialDataStoreRegistry.store.destinationPOI(forReferenceID: id)
    }

    func destinationEntityKey(forReferenceID id: String) -> String? {
        SpatialDataStoreRegistry.store.destinationEntityKey(forReferenceID: id)
    }

    func destinationIsTemporary(forReferenceID id: String) -> Bool {
        SpatialDataStoreRegistry.store.destinationIsTemporary(forReferenceID: id)
    }

    func destinationNickname(forReferenceID id: String) -> String? {
        SpatialDataStoreRegistry.store.destinationNickname(forReferenceID: id)
    }

    func destinationEstimatedAddress(forReferenceID id: String) -> String? {
        SpatialDataStoreRegistry.store.destinationEstimatedAddress(forReferenceID: id)
    }

    func markReferenceEntitySelected(forReferenceID id: String) throws {
        try SpatialDataStoreRegistry.store.markReferenceEntitySelected(forReferenceID: id)
    }

    func setReferenceEntityTemporary(forReferenceID id: String, temporary: Bool) throws {
        try SpatialDataStoreRegistry.store.setReferenceEntityTemporary(forReferenceID: id,
                                                                       temporary: temporary)
    }

    func referenceEntityID(forGenericLocation location: GenericLocation) async -> String? {
        await DataContractRegistry.spatialRead.referenceEntity(byGenericLocation: location)?.id
    }

    func referenceEntityID(forEntityKey key: String) async -> String? {
        await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: key)?.id
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

    func removeAllTemporaryReferenceEntities() async throws {
        try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
    }
}

@MainActor
enum LocationDetailStoreAdapter {
    static func poi(byKey key: String) -> POI? {
        SpatialDataStoreRegistry.store.searchByKey(key)
    }

    static func referenceEntity(byID id: String) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByKey(id)?.domainEntity
    }

    static func referenceEntity(byEntityKey key: String) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key)?.domainEntity
    }

    static func referenceEntity(byLocation coordinate: CLLocationCoordinate2D) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByLocation(coordinate)?.domainEntity
    }

    static func markReferenceEntitySelected(forReferenceID id: String) throws {
        try SpatialDataStoreRegistry.store.markReferenceEntitySelected(forReferenceID: id)
    }

    static func markPOISelected(_ entity: SelectablePOI) throws {
        var selectablePOI = entity

        try autoreleasepool {
            let cache = try RealmHelper.getCacheRealm()
            try cache.write {
                selectablePOI.lastSelectedDate = Date()
            }
        }
    }
}
