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
struct RealmSpatialReadContract: SpatialReadContract, SpatialReadCompatibilityContract {
    func routes() -> [Route] {
        SpatialDataStoreRegistry.store.routes()
    }

    func routes() async -> [Route] {
        (self as SpatialReadCompatibilityContract).routes()
    }

    func route(byKey key: String) -> Route? {
        SpatialDataStoreRegistry.store.routeByKey(key)
    }

    func route(byKey key: String) async -> Route? {
        (self as SpatialReadCompatibilityContract).route(byKey: key)
    }

    func routeMetadata(byKey key: String) -> RouteReadMetadata? {
        guard let route = SpatialDataStoreRegistry.store.routeByKey(key) else {
            return nil
        }

        return RouteReadMetadata(id: route.id, lastUpdatedDate: route.lastUpdatedDate)
    }

    func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
        (self as SpatialReadCompatibilityContract).routeMetadata(byKey: key)
    }

    func routeParameters(byKey key: String, context: RouteParameters.Context) -> RouteParameters? {
        guard let route = SpatialDataStoreRegistry.store.routeByKey(key) else {
            return nil
        }

        return RouteParameters(route: route, context: context)
    }

    func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
        (self as SpatialReadCompatibilityContract).routeParameters(byKey: key, context: context)
    }

    func routeParametersForBackup() -> [RouteParameters] {
        SpatialDataStoreRegistry.store.routes().compactMap { RouteParameters(route: $0, context: .backup) }
    }

    func routeParametersForBackup() async -> [RouteParameters] {
        (self as SpatialReadCompatibilityContract).routeParametersForBackup()
    }

    func routes(containingMarkerID markerID: String) -> [Route] {
        SpatialDataStoreRegistry.store.routesContaining(markerId: markerID)
    }

    func routes(containingMarkerID markerID: String) async -> [Route] {
        (self as SpatialReadCompatibilityContract).routes(containingMarkerID: markerID)
    }

    func referenceEntity(byID id: String) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByKey(id)
    }

    func referenceEntity(byID id: String) async -> ReferenceEntity? {
        (self as SpatialReadCompatibilityContract).referenceEntity(byID: id)
    }

    func referenceCallout(byID id: String) -> ReferenceCalloutReadData? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return ReferenceCalloutReadData(name: marker.name, superCategory: marker.getPOI().superCategory)
    }

    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
        (self as SpatialReadCompatibilityContract).referenceCallout(byID: id)
    }

    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) -> Double? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return marker.distanceToClosestLocation(from: location.clLocation)
    }

    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
        (self as SpatialReadCompatibilityContract).distanceToClosestLocation(forMarkerID: id, from: location)
    }

    func referenceMetadata(byID id: String) -> ReferenceReadMetadata? {
        guard let referenceEntity = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return ReferenceReadMetadata(id: referenceEntity.id, lastUpdatedDate: referenceEntity.lastUpdatedDate)
    }

    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
        (self as SpatialReadCompatibilityContract).referenceMetadata(byID: id)
    }

    func referenceMetadata(byEntityKey key: String) -> ReferenceReadMetadata? {
        guard let referenceEntity = SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key) else {
            return nil
        }

        return ReferenceReadMetadata(id: referenceEntity.id, lastUpdatedDate: referenceEntity.lastUpdatedDate)
    }

    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
        (self as SpatialReadCompatibilityContract).referenceMetadata(byEntityKey: key)
    }

    func markerParameters(byID id: String) -> MarkerParameters? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return MarkerParameters(marker: marker)
    }

    func markerParameters(byID id: String) async -> MarkerParameters? {
        (self as SpatialReadCompatibilityContract).markerParameters(byID: id)
    }

    func markerParameters(byEntityKey key: String) -> MarkerParameters? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key) else {
            return nil
        }

        return MarkerParameters(marker: marker)
    }

    func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
        (self as SpatialReadCompatibilityContract).markerParameters(byEntityKey: key)
    }

    func markerParametersForBackup() -> [MarkerParameters] {
        SpatialDataStoreRegistry.store.referenceEntities().compactMap { MarkerParameters(marker: $0) }
    }

    func markerParametersForBackup() async -> [MarkerParameters] {
        (self as SpatialReadCompatibilityContract).markerParametersForBackup()
    }

    func referenceEntity(byEntityKey key: String) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key)
    }

    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
        (self as SpatialReadCompatibilityContract).referenceEntity(byEntityKey: key)
    }

    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByLocation(coordinate.clCoordinate)
    }

    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
        (self as SpatialReadCompatibilityContract).referenceEntity(byCoordinate: coordinate)
    }

    func referenceEntity(byGenericLocation location: GenericLocation) -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByGenericLocation(location)
    }

    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
        (self as SpatialReadCompatibilityContract).referenceEntity(byGenericLocation: location)
    }

    func referenceEntities() -> [ReferenceEntity] {
        SpatialDataStoreRegistry.store.referenceEntities()
    }

    func referenceEntities() async -> [ReferenceEntity] {
        (self as SpatialReadCompatibilityContract).referenceEntities()
    }

    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) -> [ReferenceEntity] {
        SpatialDataStoreRegistry.store.referenceEntitiesNear(coordinate.clCoordinate, range: rangeMeters)
    }

    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
        (self as SpatialReadCompatibilityContract).referenceEntities(near: coordinate, rangeMeters: rangeMeters)
    }

    func poi(byKey key: String) -> POI? {
        SpatialDataStoreRegistry.store.searchByKey(key)
    }

    func poi(byKey key: String) async -> POI? {
        (self as SpatialReadCompatibilityContract).poi(byKey: key)
    }

    func road(byKey key: String) -> Road? {
        SpatialDataStoreRegistry.store.roadByKey(key)
    }

    func road(byKey key: String) async -> Road? {
        (self as SpatialReadCompatibilityContract).road(byKey: key)
    }

    func intersections(forRoadKey key: String) -> [Intersection] {
        SpatialDataStoreRegistry.store.intersections(forRoadKey: key)
    }

    func intersections(forRoadKey key: String) async -> [Intersection] {
        (self as SpatialReadCompatibilityContract).intersections(forRoadKey: key)
    }

    func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) -> Intersection? {
        SpatialDataStoreRegistry.store.intersection(forRoadKey: key, atCoordinate: coordinate.clCoordinate)
    }

    func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) async -> Intersection? {
        (self as SpatialReadCompatibilityContract).intersection(forRoadKey: key, at: coordinate)
    }

    func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) -> [Intersection]? {
        let mapRegion = MKCoordinateRegion(center: region.center.clCoordinate,
                                           span: MKCoordinateSpan(latitudeDelta: region.latitudeDelta,
                                                                  longitudeDelta: region.longitudeDelta))

        return SpatialDataStoreRegistry.store.intersections(forRoadKey: key, inRegion: mapRegion)
    }

    func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) async -> [Intersection]? {
        (self as SpatialReadCompatibilityContract).intersections(forRoadKey: key, in: region)
    }

    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) -> Set<VectorTile> {
        SpatialDataStoreRegistry.store.tiles(forDestinations: forDestinations,
                                             forReferences: forReferences,
                                             at: zoomLevel,
                                             destination: destination)
    }

    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> {
        (self as SpatialReadCompatibilityContract).tiles(forDestinations: forDestinations,
                                                         forReferences: forReferences,
                                                         at: zoomLevel,
                                                         destination: destination)
    }

    func tileData(for tiles: [VectorTile]) -> [TileData] {
        SpatialDataStoreRegistry.store.tileData(for: tiles)
    }

    func tileData(for tiles: [VectorTile]) async -> [TileData] {
        (self as SpatialReadCompatibilityContract).tileData(for: tiles)
    }

    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) -> [POI] {
        SpatialDataStoreRegistry.store.genericLocationsNear(location.clLocation, range: rangeMeters)
    }

    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
        (self as SpatialReadCompatibilityContract).genericLocations(near: location, rangeMeters: rangeMeters)
    }
}
