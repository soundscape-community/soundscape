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

@MainActor
protocol RouteReadContract {
    func routes() async -> [Route]
    func route(byKey key: String) async -> Route?
    func routes(containingMarkerID markerID: String) async -> [Route]
}

@MainActor
protocol ReferenceReadContract {
    func referenceEntity(byID id: String) async -> ReferenceEntity?
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
protocol RouteReadCompatibilityContract {
    func routes() -> [Route]
    func route(byKey key: String) -> Route?
    func routes(containingMarkerID markerID: String) -> [Route]
}

@MainActor
protocol ReferenceReadCompatibilityContract {
    func referenceEntity(byID id: String) -> ReferenceEntity?
    func referenceEntity(byEntityKey key: String) -> ReferenceEntity?
    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) -> ReferenceEntity?
    func referenceEntity(byGenericLocation location: GenericLocation) -> ReferenceEntity?
    func referenceEntities() -> [ReferenceEntity]
    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) -> [ReferenceEntity]
    func poi(byKey key: String) -> POI?
}

@MainActor
protocol RoadGraphReadCompatibilityContract {
    func road(byKey key: String) -> Road?
    func intersections(forRoadKey key: String) -> [Intersection]
    func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) -> Intersection?
    func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) -> [Intersection]?
}

@MainActor
protocol TileReadCompatibilityContract {
    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) -> Set<VectorTile>
    func tileData(for tiles: [VectorTile]) -> [TileData]
    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) -> [POI]
}

@MainActor
protocol SpatialReadCompatibilityContract: RouteReadCompatibilityContract,
                                           ReferenceReadCompatibilityContract,
                                           RoadGraphReadCompatibilityContract,
                                           TileReadCompatibilityContract {}

@MainActor
protocol SpatialWriteContract {
    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) async throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String
    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String
    func removeAllTemporaryReferenceEntities() async throws
}

@MainActor
protocol SpatialWriteCompatibilityContract {
    func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String
    func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String
    func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String
    func removeAllTemporaryReferenceEntities() throws
}
