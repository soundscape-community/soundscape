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
protocol RouteReadContract: SpatialRouteReadContract {
    func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters?
    func routeParametersForBackup() async -> [RouteParameters]
}

@MainActor
protocol ReferenceReadContract: SpatialReferenceReadContract,
                                SpatialReferenceMarkerReadContract
where MarkerParametersValue == MarkerParameters {
    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity?
    func recentlySelectedPOIs() async -> [POI]
    func poi(byKey key: String) async -> POI?
}

@MainActor
protocol TileReadContract: SpatialTileReadContract where Tile == VectorTile, NearbyLocation == POI {}

@MainActor
protocol SpatialReadContract: RouteReadContract,
                              ReferenceReadContract,
                              TileReadContract {}

@MainActor
protocol SpatialWriteContract: SpatialRouteWriteContract {
    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String
    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String
    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws
    func removeReferenceEntity(id: String) async throws
}

@MainActor
protocol SpatialMaintenanceWriteContract: SpatialRouteMaintenanceWriteContract,
                                          SpatialAddressMaintenanceWriteContract {
    func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws
    func removeAllReferenceEntities() async throws
    func clearNewReferenceEntitiesAndRoutes() async throws
    func cleanCorruptReferenceEntities() async throws
}
