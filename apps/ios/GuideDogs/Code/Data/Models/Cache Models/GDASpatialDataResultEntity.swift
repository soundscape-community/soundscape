//
//  GDASpatialDataResultEntity.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SSData
import Foundation
import CoreLocation

final class GDASpatialDataResultEntity: Hashable, CustomStringConvertible {
    private var data: MapFeature

    init(data: MapFeature) {
        self.data = data
    }

    static func == (lhs: GDASpatialDataResultEntity, rhs: GDASpatialDataResultEntity) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }

    var key: String { data.key }
    var name: String { data.name }
    var names: [LocalizedMapName] { data.names }
    var nameTag: String { data.nameTag }
    var ref: String { data.ref }
    var superCategory: String { data.superCategory }
    var amenity: String { data.amenity }
    var addressLine: String? { data.addressLine }
    var streetName: String? { data.streetName }
    var latitude: CLLocationDegrees { data.latitude }
    var longitude: CLLocationDegrees { data.longitude }
    var centroidLatitude: CLLocationDegrees { data.centroidLatitude }
    var centroidLongitude: CLLocationDegrees { data.centroidLongitude }
    var roundabout: Bool {
        get { data.roundabout }
        set { data.roundabout = newValue }
    }
    var lastSelectedDate: Date?

    // MARK: - Computed Properties
    
    var geometryType: GeometryType?
    
    private var _coordinates: [Any]?
    var coordinates: [Any]? {
        if _coordinates != nil {
            return _coordinates
        }
        
        // If there aren't coordinates, there is nothing to return
        guard let coordinatesJson = data.coordinatesJson, !coordinatesJson.isEmpty else {
            return nil
        }
        
        // Get the coordinates and the geometry type from the GeoJSON object
        let parsedCoordinates = GeoJsonGeometry.coordinates(in: coordinatesJson)
        
        if let geometryType = parsedCoordinates.type {
            self.geometryType = geometryType
        }
        
        _coordinates = parsedCoordinates.points
        
        return _coordinates
    }

    private var _entrances: [POI]?
    var entrances: [POI]? {
        if _entrances != nil {
            return _entrances
        }
        
        // Only features with non-point geometries can have entrances.
        guard coordinates != nil, !data.entranceIDs.isEmpty else { return nil }
        let entranceObjects = data.entranceIDs.compactMap { SpatialDataCache.searchByKey(key: $0) }

        _entrances = entranceObjects
        
        return _entrances
    }
    
    // MARK: - Initialization
    
    convenience init(id: String, parameters: LocationParameters) {
        self.init(data: MapFeature(key: id, name: parameters.name, addressLine: parameters.address,
                                   latitude: parameters.coordinate.latitude, longitude: parameters.coordinate.longitude))
    }

    // MARK: - Geometries
    
    /// Returns whether a coordinate lies inside the entity.
    /// - note: This is only valid for entities that contain geometries, such as buildings.
    func contains(location: CLLocationCoordinate2D) -> Bool {
        guard let points = self.coordinates as? GAMultiLine else { return false }
        let coordinates = points.toCoordinates()
     
        guard !coordinates.isEmpty else { return false }
     
        return GeometryUtils.geometryContainsLocation(location: location, coordinates: coordinates.first!)
    }
    
    // MARK: Debugging
    
    var description: String {
        return "{\tName: \(name)\n\tID: \(key)"
    }
    
    // Adds the ability to show the location in Xcode's debug quick look (shown as a map with a marker)
    func debugQuickLookObject() -> AnyObject? {
        guard let userLocation = AppContext.shared.geolocationManager.location else {
            return nil
        }
        
        return self.closestLocation(from: userLocation)
    }
}
