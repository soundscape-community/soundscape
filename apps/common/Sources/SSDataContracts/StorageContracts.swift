// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSDataDomain
import SSGeo

@MainActor
public protocol SpatialRouteReadContract {
    func routes() async -> [Route]
    func route(byKey key: String) async -> Route?
    func routeMetadata(byKey key: String) async -> RouteReadMetadata?
    func routes(containingMarkerID markerID: String) async -> [Route]
}

@MainActor
public protocol SpatialReferenceReadContract {
    func referenceEntity(byID id: String) async -> ReferenceEntity?
    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData?
    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double?
    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata?
    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata?
    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity?
    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity?
    func referenceEntities() async -> [ReferenceEntity]
    func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData?
    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity]
}

@MainActor
public protocol SpatialReferenceMarkerReadContract {
    associatedtype MarkerParametersValue

    func markerParameters(byID id: String) async -> MarkerParametersValue?
    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParametersValue?
    func markerParameters(byEntityKey key: String) async -> MarkerParametersValue?
    func markerParametersForBackup() async -> [MarkerParametersValue]
}

@MainActor
public protocol SpatialTileReadContract {
    associatedtype Tile: Hashable
    associatedtype NearbyLocation

    func tiles(forDestinations: Bool,
               forReferences: Bool,
               at zoomLevel: UInt,
               destination: ReferenceEntity?) async -> Set<Tile>
    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [NearbyLocation]
}

@MainActor
public protocol SpatialRouteWriteContract {
    func addRoute(_ route: Route) async throws
    func deleteRoute(id: String) async throws
    func updateRoute(_ route: Route) async throws
}

@MainActor
public protocol SpatialRouteMaintenanceWriteContract {
    func importRouteFromCloud(_ route: Route) async throws
    func removeAllRoutes() async throws
}

@MainActor
public protocol SpatialAddressMaintenanceWriteContract {
    func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws
}
