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
public protocol SpatialPointOfInterestReadContract {
    associatedtype PointOfInterestValue
    associatedtype GenericLocationValue

    func referenceEntity(byGenericLocation location: GenericLocationValue) async -> ReferenceEntity?
    func recentlySelectedPOIs() async -> [PointOfInterestValue]
    func poi(byKey key: String) async -> PointOfInterestValue?
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
public protocol SpatialReferenceWriteContract {
    associatedtype GenericLocationValue

    func addReferenceEntity(entityKey: String,
                            nickname: String?,
                            estimatedAddress: String?,
                            annotation: String?) async throws -> String
    func addReferenceEntity(location: GenericLocationValue,
                            nickname: String?,
                            estimatedAddress: String?,
                            annotation: String?) async throws -> String
    func updateReferenceEntity(id: String,
                               location: SSGeoCoordinate?,
                               nickname: String?,
                               estimatedAddress: String?,
                               annotation: String?) async throws
    func removeReferenceEntity(id: String) async throws
}

@MainActor
public protocol SpatialRouteWriteContract {
    func addRoute(_ route: Route) async throws
    func deleteRoute(id: String) async throws
    func updateRoute(_ route: Route) async throws
}

@MainActor
public protocol SpatialReferenceMaintenanceWriteContract {
    associatedtype MarkerParametersValue
    associatedtype PointOfInterestValue

    func importReferenceEntityFromCloud(markerParameters: MarkerParametersValue,
                                        entity: PointOfInterestValue) async throws
    func removeAllReferenceEntities() async throws
    func clearNewReferenceEntitiesAndRoutes() async throws
    func cleanCorruptReferenceEntities() async throws
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
