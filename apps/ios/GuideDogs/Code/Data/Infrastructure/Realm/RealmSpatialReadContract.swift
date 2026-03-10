//
//  RealmSpatialReadContract.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import CoreLocation
import SSGeo

@MainActor
struct RealmSpatialReadContract: SpatialReadContract {
    func routes() async -> [Route] {
        SpatialDataCache.routes()
    }

    func route(byKey key: String) async -> Route? {
        SpatialDataCache.routeByKey(key)
    }

    func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
        guard let route = SpatialDataCache.routeByKey(key) else {
            return nil
        }

        return RouteReadMetadata(id: route.id, lastUpdatedDate: route.lastUpdatedDate)
    }

    func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
        guard let route = SpatialDataCache.routeByKey(key) else {
            return nil
        }

        return RouteParameters(route: route, context: context)
    }

    func routeParametersForBackup() async -> [RouteParameters] {
        SpatialDataCache.routes().compactMap { RouteParameters(route: $0, context: .backup) }
    }

    func routes(containingMarkerID markerID: String) async -> [Route] {
        SpatialDataCache.routesContaining(markerId: markerID)
    }

    func referenceEntity(byID id: String) async -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByKey(id)?.domainEntity
    }

    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
        guard let marker = SpatialDataCache.referenceEntityByKey(id) else {
            return nil
        }

        return ReferenceCalloutReadData(name: marker.name, superCategory: marker.getPOI().superCategory)
    }

    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
        guard let marker = SpatialDataCache.referenceEntityByKey(id) else {
            return nil
        }

        return marker.distanceToClosestLocation(from: location.clLocation)
    }

    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
        guard let referenceEntity = SpatialDataCache.referenceEntityByKey(id) else {
            return nil
        }

        return ReferenceReadMetadata(id: referenceEntity.id, lastUpdatedDate: referenceEntity.lastUpdatedDate)
    }

    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
        guard let referenceEntity = SpatialDataCache.referenceEntityByEntityKey(key) else {
            return nil
        }

        return ReferenceReadMetadata(id: referenceEntity.id, lastUpdatedDate: referenceEntity.lastUpdatedDate)
    }

    func markerParameters(byID id: String) async -> MarkerParameters? {
        guard let marker = SpatialDataCache.referenceEntityByKey(id) else {
            return nil
        }

        return MarkerParameters(marker: marker.domainEntity)
    }

    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? {
        guard let marker = SpatialDataCache.referenceEntityByLocation(coordinate.clCoordinate) else {
            return nil
        }

        return MarkerParameters(marker: marker.domainEntity)
    }

    func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
        guard let marker = SpatialDataCache.referenceEntityByEntityKey(key) else {
            return nil
        }

        return MarkerParameters(marker: marker.domainEntity)
    }

    func markerParametersForBackup() async -> [MarkerParameters] {
        SpatialDataCache.referenceEntities().compactMap { MarkerParameters(marker: $0.domainEntity) }
    }

    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByEntityKey(key)?.domainEntity
    }

    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByLocation(coordinate.clCoordinate)?.domainEntity
    }

    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByGenericLocation(location)?.domainEntity
    }

    func referenceEntities() async -> [ReferenceEntity] {
        SpatialDataCache.referenceEntities().map(\.domainEntity)
    }

    func recentlySelectedPOIs() async -> [POI] {
        SpatialDataCache.recentlySelectedObjects()
    }

    func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData? {
        await withCheckedContinuation { continuation in
            SpatialDataCache.fetchEstimatedAddress(location: location.clLocation) { address in
                continuation.resume(returning: address.map {
                    EstimatedAddressReadData(addressLine: $0.addressLine,
                                             streetName: $0.streetName,
                                             subThoroughfare: $0.subThoroughfare)
                })
            }
        }
    }

    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
        SpatialDataCache.referenceEntitiesNear(coordinate.clCoordinate, range: rangeMeters).map(\.domainEntity)
    }

    func poi(byKey key: String) async -> POI? {
        SpatialDataCache.searchByKey(key: key)
    }

    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> {
        return SpatialDataCache.tiles(forDestinations: forDestinations,
                                      forReferences: forReferences,
                                      at: zoomLevel,
                                      destinationCoordinate: destination?.coordinate.clCoordinate)
    }

    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
        SpatialDataCache.genericLocationsNear(location.clLocation, range: rangeMeters)
    }
}

@MainActor
extension Road {
    var intersections: [Intersection] {
        SpatialDataCache.intersections(forRoadKey: key) ?? []
    }

    func intersection(atCoordinate coordinate: CLLocationCoordinate2D) -> Intersection? {
        SpatialDataCache.intersection(forRoadKey: key, atCoordinate: coordinate)
    }
}

@MainActor
enum RoadAdjacentDataStoreAdapter {
    static func markersNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance) -> [ReferenceEntity] {
        SpatialDataCache.referenceEntitiesNear(coordinate, range: range).map(\.domainEntity)
    }
}
