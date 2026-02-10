//
//  SpatialReadContracts.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSGeo

struct SpatialIntersectionRegion: Sendable {
    let center: SSGeoCoordinate
    let latitudeDelta: Double
    let longitudeDelta: Double
}

struct RouteReadMetadata: Sendable {
    let id: String
    let lastUpdatedDate: Date?
}

struct ReferenceReadMetadata: Sendable {
    let id: String
    let lastUpdatedDate: Date?
}

struct ReferenceCalloutReadData: Sendable {
    let name: String
    let superCategory: String
}

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
    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity]
    func poi(byKey key: String) async -> POI?
}

@MainActor
protocol RoadGraphReadContract {
    func road(byKey key: String) async -> Road?
    func intersections(forRoadKey key: String) async -> [Intersection]
    func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) async -> Intersection?
    func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) async -> [Intersection]?
}

@MainActor
protocol TileReadContract {
    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile>
    func tileData(for tiles: [VectorTile]) async -> [TileData]
    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI]
}

@MainActor
protocol SpatialReadContract: RouteReadContract,
                              ReferenceReadContract,
                              RoadGraphReadContract,
                              TileReadContract {}

@MainActor
@available(*, deprecated, message: "Temporary compatibility seam. Use async RouteReadContract APIs instead.")
protocol RouteReadCompatibilityContract {
    func routes() -> [Route]
    func route(byKey key: String) -> Route?
    func routeMetadata(byKey key: String) -> RouteReadMetadata?
    func routeParameters(byKey key: String, context: RouteParameters.Context) -> RouteParameters?
    func routeParametersForBackup() -> [RouteParameters]
    func routes(containingMarkerID markerID: String) -> [Route]
}

@MainActor
@available(*, deprecated, message: "Temporary compatibility seam. Use async ReferenceReadContract APIs instead.")
protocol ReferenceReadCompatibilityContract {
    func referenceEntity(byID id: String) -> RealmReferenceEntity?
    func referenceCallout(byID id: String) -> ReferenceCalloutReadData?
    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) -> Double?
    func referenceMetadata(byID id: String) -> ReferenceReadMetadata?
    func referenceMetadata(byEntityKey key: String) -> ReferenceReadMetadata?
    func markerParameters(byID id: String) -> MarkerParameters?
    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) -> MarkerParameters?
    func markerParameters(byEntityKey key: String) -> MarkerParameters?
    func markerParametersForBackup() -> [MarkerParameters]
    func referenceEntity(byEntityKey key: String) -> RealmReferenceEntity?
    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) -> RealmReferenceEntity?
    func referenceEntity(byGenericLocation location: GenericLocation) -> RealmReferenceEntity?
    func referenceEntities() -> [RealmReferenceEntity]
    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) -> [RealmReferenceEntity]
    func poi(byKey key: String) -> POI?
}

@MainActor
@available(*, deprecated, message: "Temporary compatibility seam. Use async RoadGraphReadContract APIs instead.")
protocol RoadGraphReadCompatibilityContract {
    func road(byKey key: String) -> Road?
    func intersections(forRoadKey key: String) -> [Intersection]
    func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) -> Intersection?
    func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) -> [Intersection]?
}

@MainActor
@available(*, deprecated, message: "Temporary compatibility seam. Use async TileReadContract APIs instead.")
protocol TileReadCompatibilityContract {
    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: RealmReferenceEntity?) -> Set<VectorTile>
    func tileData(for tiles: [VectorTile]) -> [TileData]
    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) -> [POI]
}

@MainActor
@available(*, deprecated, message: "Temporary compatibility seam. Use async SpatialReadContract APIs instead.")
protocol SpatialReadCompatibilityContract: RouteReadCompatibilityContract,
                                           ReferenceReadCompatibilityContract,
                                           RoadGraphReadCompatibilityContract,
                                           TileReadCompatibilityContract {}

@MainActor
protocol SpatialWriteContract {
    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) async throws -> String
    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?) async throws -> String
    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?, temporary: Bool, context: String?) async throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String
    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String
    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?, isTemp: Bool) async throws
    func removeAllReferenceEntities() async throws
    func removeAllRoutes() async throws
    func cleanCorruptReferenceEntities() async throws
    func removeReferenceEntity(id: String) async throws
    func removeAllTemporaryReferenceEntities() async throws
}

@MainActor
@available(*, deprecated, message: "Temporary compatibility seam. Use async SpatialWriteContract APIs instead.")
protocol SpatialWriteCompatibilityContract {
    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) throws -> String
    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?) throws -> String
    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?, temporary: Bool, context: String?) throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String
    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String
    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?, context: String?, isTemp: Bool) throws
    func removeAllReferenceEntities() throws
    func removeAllRoutes() throws
    func cleanCorruptReferenceEntities() throws
    func removeReferenceEntity(id: String) throws
    func removeAllTemporaryReferenceEntities() throws
}
