//
//  SpatialDataCache.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import MapKit
import SSData

final class SpatialDataCache {
    private static var geocoder: Geocoder?
    
    static func useDefaultGeocoder() {
        self.geocoder = Geocoder(geocoder: CLGeocoder())
    }
    
    static func register(geocoder: AddressGeocoderProtocol) {
        self.geocoder = Geocoder(geocoder: geocoder)
    }
    

    private static var testProviders: [POISearchProviderProtocol] = []

    static func register(provider: POISearchProviderProtocol) {
        guard !testProviders.contains(where: { $0.providerName == provider.providerName }) else { return }
        testProviders.append(provider)
    }

    static func removeAllProviders() {
        testProviders.removeAll()
    }

    static func recordSelection(_ poi: POI, at date: Date = Date()) {
        guard poi is GDASpatialDataResultEntity else { return }
        let key = poi.key
        DispatchQueue.global(qos: .utility).async {
            do {
                try StorageContext.shared.spatial().recordSelection(key: key, at: date)
            } catch {
                GDLogSpatialDataError("Unable to record map selection: \(error)")
            }
        }
    }

    static func recentlySelectedObjects() -> [POI] {
        let mapEntries: [(String, Date)] = spatialRead { try $0.recentSelections(limit: 5) } ?? []
        let mapPlaces: [(POI, Date)] = mapEntries.compactMap { key, date in
            searchMapByKey(key).map { ($0, date) }
        }
        let markerPlaces: [(POI, Date)] = StorageContext.shared.markers.compactMap { marker in
            guard !marker.isTemp, let date = marker.lastSelectedDate,
                  marker.entityKey == nil || marker.place != nil else { return nil }
            return (ReferenceEntity(stored: marker).getPOI(), date)
        }
        var keys: Set<String> = []
        return (mapPlaces + markerPlaces).sorted { $0.1 > $1.1 }.map(\.0)
            .filter { keys.insert($0.key).inserted }.prefix(5).map { $0 }
    }

    static func searchMapByKey(_ key: String) -> POI? {
        if let supplied = testProviders.lazy.compactMap({ $0.search(byKey: key) }).first { return supplied }
        return entity(key, kinds: [.poi, .road, .path])
    }

    static func searchByKey(key: String) -> POI? {
        searchMapByKey(key) ?? referenceEntityByEntityKey(key)?.restoredPOI
            ?? referenceEntityByKey(key)?.getPOI()
    }

    static func road(withKey key: String) -> Road? {
        entity(key, kinds: [.road, .path])
    }

    private static func entity(_ key: String, kinds: [TileFeature.Kind]) -> GDASpatialDataResultEntity? {
        spatialRead {
            guard let feature = try $0.feature(key: key, kinds: kinds) else { return nil }
            return try JSONDecoder().decode(GDASpatialDataResultEntity.self, from: feature.payload)
        }
    }

    static func routeByKey(_ key: String) -> Route? {
        StorageContext.shared.routes.first { $0.id == key }.map(Route.init(saved:))
    }

    static func routesNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance) -> [Route] {
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: range * 2, longitudinalMeters: range * 2)
        return StorageContext.shared.routes.map(Route.init(saved:)).filter {
            guard let latitude = $0.firstWaypointLatitude, let longitude = $0.firstWaypointLongitude else { return false }
            return contains(region, latitude: latitude, longitude: longitude)
        }
    }

    static func routesContaining(markerId: String) -> [Route] {
        StorageContext.shared.routes.filter { route in route.waypoints.contains { $0.markerId == markerId } }
            .map(Route.init(saved:))
    }

    static func clearNewRoutes() throws {
        try StorageContext.shared.write { try $0.clearNewRoutes() }
    }

    static func clearNewReferenceEntities() throws {
        try StorageContext.shared.write { try $0.clearNewMarkers() }
    }

    static func containsReferenceEntity(withKey key: String) -> Bool {
        referenceEntityByKey(key) != nil
    }

    static func referenceEntities(isTemp: Bool = false) -> [ReferenceEntity] {
        StorageContext.shared.markers.filter { $0.isTemp == isTemp }.map(ReferenceEntity.init(stored:))
    }

    static func referenceEntityByKey(_ key: String) -> ReferenceEntity? {
        StorageContext.shared.markers.first { $0.id == key }.map(ReferenceEntity.init(stored:))
    }

    static func referenceEntityByEntityKey(_ key: String) -> ReferenceEntity? {
        let markers = StorageContext.shared.markers
        return (markers.first { $0.entityKey == key } ?? markers.first { $0.id == key }).map(ReferenceEntity.init(stored:))
    }

    static func referenceEntityByLocation(_ coordinate: CLLocationCoordinate2D, isTemp: Bool? = false) -> ReferenceEntity? {
        return referenceEntitiesNear(coordinate, range: 1.0, isTemp: isTemp).first
    }
    
    ///
    /// Returns reference entity objects near the given location and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - location returns objects near the given location
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntityByGenericLocation(_ location: GenericLocation, isTemp: Bool? = false) -> ReferenceEntity? {
        return referenceEntityByLocation(location.location.coordinate, isTemp: isTemp)
    }
    
    ///
    /// Returns reference entity objects matching the given source and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - source defines what the reference entity is based on
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntity(source: LocationDetail.Source, isTemp: Bool? = false) -> ReferenceEntity? {
        var marker: ReferenceEntity?
        
        switch source {
        case .entity(let id): marker = SpatialDataCache.referenceEntityByEntityKey(id)
        case .coordinate(let location): marker = SpatialDataCache.referenceEntityByLocation(location.coordinate, isTemp: isTemp)
        case .designData: marker = nil
        case .screenshots(let poi): marker = SpatialDataCache.referenceEntityByEntityKey(poi.key)
        }
        
        if let isTemp = isTemp, let marker = marker {
            // Only return markers with the given value for `isTemp`
            return marker.isTemp == isTemp ? marker : nil
        } else {
            // Do not filter by `isTemp`
            return marker
        }
    }
    
    ///
    /// Returns reference entity objects near the given coordinate and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - coordinate returns objects near the given coordiante
    /// - range search distance in meters
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntitiesNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance, isTemp: Bool? = false) -> [ReferenceEntity] {
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: range * 2, longitudinalMeters: range * 2)
        return StorageContext.shared.markers.filter { marker in
            (isTemp == nil || marker.isTemp == isTemp) &&
                contains(region, latitude: marker.latitude, longitude: marker.longitude)
        }.map(ReferenceEntity.init(stored:))
    }


    static func genericLocationsNear(_ location: CLLocation, range: CLLocationDistance? = nil) -> [POI] {
        referenceEntitiesNear(location.coordinate, range: range ?? SpatialDataContext.cacheDistance)
            .filter { $0.entityKey == nil }.map { $0.getPOI() }
    }

    static func intersectionByKey(_ key: String) -> Intersection? {
        spatialRead {
            guard let feature = try $0.feature(key: key, kinds: [.intersection]) else { return nil }
            return try JSONDecoder().decode(Intersection.self, from: feature.payload)
        }
    }

    static func intersection(forRoadKey roadKey: String, atCoordinate coordinate: CLLocationCoordinate2D) -> Intersection? {
        intersections(forRoadKey: roadKey)?.first { $0.coordinate == coordinate }
    }

    static func intersections(forRoadKey roadKey: String, inRegion region: MKCoordinateRegion? = nil) -> [Intersection]? {
        spatialRead {
            let decoder = JSONDecoder()
            return try $0.intersections(roadKey: roadKey).map { try decoder.decode(Intersection.self, from: $0.payload) }
                .filter { intersection in
                    guard let region else { return true }
                    return contains(region, latitude: intersection.latitude, longitude: intersection.longitude)
                }
        }
    }

    private static func contains(_ region: MKCoordinateRegion, latitude: Double, longitude: Double) -> Bool {
        let longitudeOffset = abs((longitude - region.center.longitude).truncatingRemainder(dividingBy: 360))
        return abs(latitude - region.center.latitude) <= region.span.latitudeDelta / 2
            && min(longitudeOffset, 360 - longitudeOffset) <= region.span.longitudeDelta / 2
    }

    static func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt) -> Set<VectorTile> {
        var tiles: Set<VectorTile> = []
        
        if forReferences {
            let porTiles = SpatialDataCache.tilesForReferenceEntities(at: zoomLevel)
            for porTile in porTiles {
                tiles.insert(porTile)
            }
        }
        
        let manager = AppContext.shared.spatialDataContext.destinationManager
        if forDestinations, let destination = manager.destination {
            tiles.insert(VectorTile(latitude: destination.latitude, longitude: destination.longitude, zoom: zoomLevel))
        }
        
        return tiles
    }
    
    static func tilesForReferenceEntities(at zoomLevel: UInt) -> Set<VectorTile> {
        let referenceEntities = SpatialDataCache.referenceEntities()
        let tiles = referenceEntities.map { VectorTile(latitude: $0.latitude, longitude: $0.longitude, zoom: zoomLevel) }
        return Set(tiles)
    }
    

    static func tileData(for tiles: [VectorTile]) -> [TileData] {
        spatialRead {
            try $0.tiles(keys: tiles.map(\.quadKey)).map { try TileData(key: $0.0, metadata: $0.1, features: $0.2) }
        } ?? []
    }

    static func isAddress(poi: POI) -> Bool {
        poi is Address
    }

    private static func spatialRead<T>(_ read: (SpatialTileStore) throws -> T?) -> T? {
        do {
            return try StorageContext.shared.withSpatialStore(read)
        } catch {
            GDLogSpatialDataError("Spatial database read failed: \(error)")
            return nil
        }
    }

    static func fetchEstimatedCoordinate(address: String, in region: CLRegion? = nil, completionHandler: @escaping (GeocodedAddress?) -> Void) {
        guard let geocoder = geocoder else {
            GDLogSpatialDataError("Geocode Coordinate Error - Geocoder has not been initialized")
            
            completionHandler(nil)
            return
        }
        
        geocoder.geocodeAddressString(address: address, in: region) { (results) in
            guard let results = results  else {
                GDLogSpatialDataError("Geocode Coordinate Error - No results returned")

                completionHandler(nil)
                return
            }
            
            completionHandler(results.first)
        }
    }
    
    static func fetchEstimatedAddress(location: CLLocation, completionHandler: @escaping (GeocodedAddress?) -> Void) {
        guard let geocoder = geocoder else {
            GDLogSpatialDataError("Geocode Address Error - Geocoder has not been initialized")
            
            completionHandler(nil)
            return
        }
        
        geocoder.geocodeLocation(location: location) { (results) in
            guard let results = results  else {
                GDLogSpatialDataError("Geocode Address Error - No results returned")
                
                completionHandler(nil)
                return
            }
            
            completionHandler(results.first)
        }
    }
    
}
