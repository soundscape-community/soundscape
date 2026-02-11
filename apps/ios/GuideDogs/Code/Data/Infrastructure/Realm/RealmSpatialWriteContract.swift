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
        let firstWaypointCoordinate = await resolveFirstWaypointCoordinate(for: route)
        try Route.add(route, firstWaypointCoordinate: firstWaypointCoordinate)
    }

    func importRouteFromCloud(_ route: Route) async throws {
        let firstWaypointCoordinate = await resolveFirstWaypointCoordinate(for: route)
        try Route.importFromCloud(route, firstWaypointCoordinate: firstWaypointCoordinate)
    }

    func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws {
        try RealmReferenceEntity.importFromCloud(markerParameters: markerParameters, entity: entity)
    }

    func deleteRoute(id: String) async throws {
        try Route.delete(id)
    }

    func updateRoute(_ route: Route) async throws {
        let firstWaypointCoordinate = await resolveFirstWaypointCoordinate(for: route)
        try Route.update(id: route.id,
                         name: route.name,
                         description: route.routeDescription,
                         waypoints: route.waypoints.asLocationDetail,
                         firstWaypointCoordinate: firstWaypointCoordinate)
    }

    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
        try RealmReferenceEntity.add(entityKey: entityKey,
                                     nickname: nickname,
                                     estimatedAddress: estimatedAddress,
                                     annotation: annotation,
                                     context: nil)
    }

    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
        try RealmReferenceEntity.add(location: location,
                                     nickname: nickname,
                                     estimatedAddress: estimatedAddress,
                                     annotation: annotation,
                                     temporary: false,
                                     context: nil)
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
        try await RealmReferenceEntity.cleanCorruptEntities(using: DataContractRegistry.spatialRead)
    }

    func removeReferenceEntity(id: String) async throws {
        try await RealmReferenceEntity.remove(id: id, using: DataContractRegistry.spatialRead)
    }

    private func resolveFirstWaypointCoordinate(for route: Route) async -> CLLocationCoordinate2D? {
        await Route.firstWaypointCoordinate(for: route.waypoints, using: DataContractRegistry.spatialRead)
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
