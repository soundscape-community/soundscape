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

    func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
        guard let route = SpatialDataStoreRegistry.store.routeByKey(key) else {
            return nil
        }

        return RouteReadMetadata(id: route.id, lastUpdatedDate: route.lastUpdatedDate)
    }

    func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
        guard let route = SpatialDataStoreRegistry.store.routeByKey(key) else {
            return nil
        }

        return RouteParameters(route: route, context: context)
    }

    func routeParametersForBackup() async -> [RouteParameters] {
        SpatialDataStoreRegistry.store.routes().compactMap { RouteParameters(route: $0, context: .backup) }
    }

    func routes(containingMarkerID markerID: String) async -> [Route] {
        SpatialDataStoreRegistry.store.routesContaining(markerId: markerID)
    }

    func referenceEntity(byID id: String) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByKey(id)?.domainEntity
    }

    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return ReferenceCalloutReadData(name: marker.name, superCategory: marker.getPOI().superCategory)
    }

    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return marker.distanceToClosestLocation(from: location.clLocation)
    }

    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
        guard let referenceEntity = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return ReferenceReadMetadata(id: referenceEntity.id, lastUpdatedDate: referenceEntity.lastUpdatedDate)
    }

    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
        guard let referenceEntity = SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key) else {
            return nil
        }

        return ReferenceReadMetadata(id: referenceEntity.id, lastUpdatedDate: referenceEntity.lastUpdatedDate)
    }

    func markerParameters(byID id: String) async -> MarkerParameters? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) else {
            return nil
        }

        return MarkerParameters(marker: marker)
    }

    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByLocation(coordinate.clCoordinate) else {
            return nil
        }

        return MarkerParameters(marker: marker)
    }

    func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
        guard let marker = SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key) else {
            return nil
        }

        return MarkerParameters(marker: marker)
    }

    func markerParametersForBackup() async -> [MarkerParameters] {
        SpatialDataStoreRegistry.store.referenceEntities().compactMap { MarkerParameters(marker: $0) }
    }

    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByEntityKey(key)?.domainEntity
    }

    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByLocation(coordinate.clCoordinate)?.domainEntity
    }

    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
        SpatialDataStoreRegistry.store.referenceEntityByGenericLocation(location)?.domainEntity
    }

    func referenceEntities() async -> [ReferenceEntity] {
        SpatialDataStoreRegistry.store.referenceEntities().map(\.domainEntity)
    }

    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
        SpatialDataStoreRegistry.store.referenceEntitiesNear(coordinate.clCoordinate, range: rangeMeters).map(\.domainEntity)
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
        return SpatialDataStoreRegistry.store.tiles(forDestinations: forDestinations,
                                                    forReferences: forReferences,
                                                    at: zoomLevel,
                                                    destinationCoordinate: destination?.coordinate.clCoordinate)
    }

    func tileData(for tiles: [VectorTile]) async -> [TileData] {
        SpatialDataStoreRegistry.store.tileData(for: tiles)
    }

    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
        SpatialDataStoreRegistry.store.genericLocationsNear(location.clLocation, range: rangeMeters)
    }
}
