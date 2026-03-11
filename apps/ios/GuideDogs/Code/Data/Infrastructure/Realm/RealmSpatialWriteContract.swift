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
        try await RealmReferenceEntity.update(id: id,
                                              location: location?.clCoordinate,
                                              nickname: nickname,
                                              address: estimatedAddress,
                                              annotation: annotation,
                                              context: nil,
                                              isTemp: false,
                                              using: DataContractRegistry.spatialRead)
    }

    func markReferenceEntitySelected(id: String) async throws {
        try RealmReferenceEntity.markSelected(id: id)
    }

    func markPointOfInterestSelected(entityKey: String) async throws {
        guard let selectablePOI = await DataContractRegistry.spatialRead.poi(byKey: entityKey) as? SelectablePOI else {
            return
        }

        var mutablePOI = selectablePOI

        try autoreleasepool {
            let cache = try RealmHelper.getCacheRealm()
            try cache.write {
                mutablePOI.lastSelectedDate = Date()
            }
        }
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

    func materializePointOfInterest(from location: LocationParameters) async throws -> POI {
        if let entity = location.entity {
            switch entity.source {
            case .osm:
                if let existingPOI = await DataContractRegistry.spatialRead.poi(byKey: entity.lookupInformation) {
                    return existingPOI
                }

                return try GDASpatialDataResultEntity.addOrUpdateSpatialCacheEntity(
                    id: entity.lookupInformation,
                    parameters: location
                )
            }
        }

        return GenericLocation(lat: location.coordinate.latitude,
                               lon: location.coordinate.longitude,
                               name: location.name)
    }

    func removeAllReferenceEntities() async throws {
        // Clear the destination before deleting markers to preserve existing cache-reset behavior.
        try await ReferenceEntityRuntime.clearDestinationForCacheReset()

        let database = try RealmHelper.getDatabaseRealm()

        // Route cleanup is handled separately by callers that invoke `removeAllRoutes`.
        for entity in database.objects(RealmReferenceEntity.self) {
            let id = entity.id

            ReferenceEntityRuntime.removeReferenceFromCloud(markerID: id)

            try database.write {
                database.delete(entity)
            }

            ReferenceEntityRuntime.didRemoveReferenceEntity(id: id)
        }
    }

    func removeAllRoutes() async throws {
        let routes = await DataContractRegistry.spatialRead.routes()

        for route in routes {
            try Route.delete(route.id)
        }
    }

    func clearNewReferenceEntitiesAndRoutes() async throws {
        try RealmReferenceEntity.clearNew()
        try Route.clearNew()
    }

    func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws {
        guard let cache = try? RealmHelper.getCacheRealm() else {
            throw RouteDataError.databaseError
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
        RealmReferenceEntity.entity(byID: id)?.getPOI()
    }

    func destinationEntityKey(forReferenceID id: String) -> String? {
        RealmReferenceEntity.entity(byID: id)?.entityKey
    }

    func destinationIsTemporary(forReferenceID id: String) -> Bool {
        RealmReferenceEntity.entity(byID: id)?.isTemp ?? false
    }

    func destinationNickname(forReferenceID id: String) -> String? {
        RealmReferenceEntity.entity(byID: id)?.nickname
    }

    func destinationEstimatedAddress(forReferenceID id: String) -> String? {
        RealmReferenceEntity.entity(byID: id)?.estimatedAddress
    }

    func markReferenceEntitySelected(forReferenceID id: String) throws {
        try RealmReferenceEntity.markSelected(id: id)
    }

    func setReferenceEntityTemporary(forReferenceID id: String, temporary: Bool) throws {
        try RealmReferenceEntity.setTemporary(id: id, temporary: temporary)
    }

    func referenceEntityID(forGenericLocation location: GenericLocation) async -> String? {
        await DataContractRegistry.spatialRead.referenceEntity(byGenericLocation: location)?.id
    }

    func referenceEntityID(forEntityKey key: String) async -> String? {
        await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: key)?.id
    }

    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String {
        try await RealmReferenceEntity.add(location: location,
                                           nickname: nil,
                                           estimatedAddress: estimatedAddress,
                                           annotation: nil,
                                           temporary: true,
                                           context: nil,
                                           using: DataContractRegistry.spatialRead)
    }

    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String {
        try await RealmReferenceEntity.add(location: location,
                                           nickname: nickname,
                                           estimatedAddress: estimatedAddress,
                                           annotation: nil,
                                           temporary: true,
                                           context: nil,
                                           using: DataContractRegistry.spatialRead)
    }

    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String {
        try await RealmReferenceEntity.add(entityKey: entityKey,
                                           nickname: nil,
                                           estimatedAddress: estimatedAddress,
                                           annotation: nil,
                                           temporary: true,
                                           context: nil,
                                           using: DataContractRegistry.spatialRead)
    }

    func removeAllTemporaryReferenceEntities() async throws {
        try RealmReferenceEntity.removeAllTemporary()
    }
}

@MainActor
enum LocationDetailStoreAdapter {
    static func poi(byKey key: String) -> POI? {
        SpatialDataCache.searchByKey(key: key)
    }

    static func referenceEntity(byID id: String) -> ReferenceEntity? {
        RealmReferenceEntity.entity(byID: id)?.domainEntity
    }

    static func referenceEntity(byEntityKey key: String) -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByEntityKey(key)?.domainEntity
    }

    static func referenceEntity(byLocation coordinate: CLLocationCoordinate2D) -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByLocation(coordinate)?.domainEntity
    }

    static func markReferenceEntitySelected(forReferenceID id: String) throws {
        try RealmReferenceEntity.markSelected(id: id)
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
