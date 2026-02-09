//
//  RealmSpatialReadContract.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import CoreLocation
import MapKit
import SSGeo

@MainActor
struct RealmSpatialReadContract: SpatialReadContract {
    func routes() async -> [Route] {
        SpatialDataStoreRegistry.store.routes()
    }

    func route(byKey key: String) async -> Route? {
        SpatialDataStoreRegistry.store.routeByKey(key)
    }

    func routes(containingMarkerID markerID: String) async -> [Route] {
        SpatialDataStoreRegistry.store.routesContaining(markerId: markerID)
    }

    func referenceEntity(byID id: String) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByKey(id)
    }

    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key)
    }

    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByLocation(coordinate.clCoordinate)
    }

    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByGenericLocation(location)
    }

    func referenceEntities() async -> [ReferenceEntity] {
        SpatialDataStoreRegistry.store.referenceEntities()
    }

    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
        SpatialDataStoreRegistry.store.referenceEntitiesNear(coordinate.clCoordinate, range: rangeMeters)
    }

    func poi(byKey key: String) async -> POI? {
        SpatialDataStoreRegistry.store.searchByKey(key)
    }

    func road(byKey key: String) async -> Road? {
        SpatialDataStoreRegistry.store.roadByKey(key)
    }

    func intersections(forRoadKey key: String) async -> [Intersection] {
        SpatialDataStoreRegistry.store.intersections(forRoadKey: key)
    }

    func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) async -> Intersection? {
        SpatialDataStoreRegistry.store.intersection(forRoadKey: key, atCoordinate: coordinate.clCoordinate)
    }

    func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) async -> [Intersection]? {
        let mapRegion = MKCoordinateRegion(center: region.center.clCoordinate,
                                           span: MKCoordinateSpan(latitudeDelta: region.latitudeDelta,
                                                                  longitudeDelta: region.longitudeDelta))

        return SpatialDataStoreRegistry.store.intersections(forRoadKey: key, inRegion: mapRegion)
    }

    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> {
        SpatialDataStoreRegistry.store.tiles(forDestinations: forDestinations,
                                             forReferences: forReferences,
                                             at: zoomLevel,
                                             destination: destination)
    }

    func tileData(for tiles: [VectorTile]) async -> [TileData] {
        SpatialDataStoreRegistry.store.tileData(for: tiles)
    }

    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
        SpatialDataStoreRegistry.store.genericLocationsNear(location.clLocation, range: rangeMeters)
    }
}
