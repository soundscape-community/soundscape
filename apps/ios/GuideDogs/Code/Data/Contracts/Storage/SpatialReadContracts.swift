//
//  SpatialReadContracts.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSDataContracts
import SSGeo

typealias SpatialIntersectionRegion = SSDataContracts.SpatialIntersectionRegion
typealias RouteReadMetadata = SSDataContracts.RouteReadMetadata
typealias ReferenceReadMetadata = SSDataContracts.ReferenceReadMetadata
typealias ReferenceCalloutReadData = SSDataContracts.ReferenceCalloutReadData
typealias EstimatedAddressReadData = SSDataContracts.EstimatedAddressReadData
typealias AddressCacheRecord = SSDataContracts.AddressCacheRecord

@MainActor
protocol RouteReadContract {
    func routes() async -> [Route]
    func route(byKey key: String) async -> Route?
    func routeMetadata(byKey key: String) async -> RouteReadMetadata?
    func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters?
    func routeParametersForBackup() async -> [RouteParameters]
    func routes(containingMarkerID markerID: String) async -> [Route]
}

@MainActor
protocol ReferenceReadContract {
    func referenceEntity(byID id: String) async -> ReferenceEntity?
    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData?
    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double?
    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata?
    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata?
    func markerParameters(byID id: String) async -> MarkerParameters?
    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters?
    func markerParameters(byEntityKey key: String) async -> MarkerParameters?
    func markerParametersForBackup() async -> [MarkerParameters]
    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity?
    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity?
    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity?
    func referenceEntities() async -> [ReferenceEntity]
    func recentlySelectedPOIs() async -> [POI]
    func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData?
    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity]
    func poi(byKey key: String) async -> POI?
}

@MainActor
protocol TileReadContract {
    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile>
    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI]
}

@MainActor
protocol SpatialReadContract: RouteReadContract,
                              ReferenceReadContract,
                              TileReadContract {}

@MainActor
protocol SpatialWriteContract {
    func addRoute(_ route: Route) async throws
    func deleteRoute(id: String) async throws
    func updateRoute(_ route: Route) async throws
    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String
    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String
    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws
    func removeReferenceEntity(id: String) async throws
}

@MainActor
protocol SpatialMaintenanceWriteContract {
    func importRouteFromCloud(_ route: Route) async throws
    func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws
    func removeAllReferenceEntities() async throws
    func removeAllRoutes() async throws
    func clearNewReferenceEntitiesAndRoutes() async throws
    func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws
    func cleanCorruptReferenceEntities() async throws
}
