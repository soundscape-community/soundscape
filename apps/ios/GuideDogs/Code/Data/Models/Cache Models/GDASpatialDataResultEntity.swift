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

final class LocalizedString: Codable {
    /// Lowercase ISO 639-1 alpha2 code (second column), or a lowercase ISO 639-2 code if an ISO 639-1 code doesn't exist.
    /// http://www.loc.gov/standards/iso639-2/php/code_list.php
    var language: String = ""
    var string: String = ""

    convenience init(language: String, string: String) {
        self.init()
    
        self.language = language
        self.string = string
    }
}

final class GDASpatialDataResultEntity: Codable, Hashable, CustomStringConvertible {
    
    static func == (lhs: GDASpatialDataResultEntity, rhs: GDASpatialDataResultEntity) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }

    private enum CodingKeys: String, CodingKey {
        case key, name, names, nameTag, ref, superCategory, amenity, phone, addressLine, streetName, roundabout
        case coordinatesJson, entrancesJson, dynamicURL, dynamicData, latitude, longitude, centroidLatitude, centroidLongitude
    }

    // MARK: - Properties

    var key: String = UUID().uuidString
    var lastSelectedDate: Date?
    /// The default entity name
    var name: String = ""
    /// Array of localized entity names. e.g. `["en": "Louvre Museum", "fr": "Musée du Louvre"]`
    var names: [LocalizedString] = []
    /// For some OSM entities (i.e. "Road", "Walking Path" and "Bus stop")
    /// we also store the type (i.e, "road", "walking_path", "bus_stop")
    /// so we can localize and display the name correctly.
    var nameTag: String = ""
    /// "ref" stands for "reference" and is used for reference numbers or codes.
    /// Common for roads, highway exits, routes, etc. It is also used for shops and amenities
    /// that are numbered officially as part of a retail brand or network respectively.
    /// - note: https://wiki.openstreetmap.org/wiki/Key:ref
    var ref: String = ""
    var superCategory: String = SuperCategory.undefined.rawValue
    var amenity: String!
    var phone: String?
    var addressLine: String?
    var streetName: String?
    var roundabout: Bool = false
    var coordinatesJson: String?
    var entrancesJson: String?
    var dynamicURL: String?
    var dynamicData: String?
    var latitude: CLLocationDegrees = 0.0
    var longitude: CLLocationDegrees = 0.0
    var centroidLatitude: CLLocationDegrees = 0.0
    var centroidLongitude: CLLocationDegrees = 0.0

    // MARK: - Computed Properties
    
    var geometryType: GeometryType?
    
    private var _coordinates: [Any]?
    var coordinates: [Any]? {
        if _coordinates != nil {
            return _coordinates
        }
        
        // If there aren't coordinates, there is nothing to return
        guard let coordinatesJson = coordinatesJson, !coordinatesJson.isEmpty else {
            return nil
        }
        
        // Get the coordinates and the geometry type from the GeoJSON object
        let parsedCoordinates = GeometryUtils.coordinates(geoJson: coordinatesJson)
        
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
        
        // Only POIs with non-point geometries can have entrances
        guard coordinates != nil,
            let jsonData = entrancesJson?.data(using: .utf8) else {
            return nil
        }
        
        guard let entranceIDs = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            return nil
        }
        
        var entranceObjects = [POI]()
        for entranceID in entranceIDs {
            if let entrance = SpatialDataCache.searchByKey(key: entranceID) {
                entranceObjects.append(entrance)
            }
        }
        
        _entrances = entranceObjects
        
        return _entrances
    }
    
    // MARK: - Initialization
    
    convenience init(id: String, parameters: LocationParameters) {
        self.init()
        
        key = id
        name = parameters.name
        self.latitude = parameters.coordinate.latitude
        self.longitude = parameters.coordinate.longitude
        centroidLatitude = parameters.coordinate.latitude
        centroidLongitude = parameters.coordinate.longitude
        superCategory = SuperCategory.undefined.rawValue
        amenity = ""
        addressLine = parameters.address
    }
    
    convenience init?(feature: GeoJsonFeature, key: String? = nil) {
        self.init()
        
        if let key = key {
            self.key = key
        } else if let firstId = feature.osmIds.first {
            self.key = firstId
        } else {
            return nil
        }
        
        guard !self.key.isEmpty else {
            return nil
        }
        
        superCategory = feature.superCategory.rawValue
        amenity = feature.value
        
        if let featureName = feature.name {
            name = featureName
        }
        
        if let localizedNames = feature.names, !localizedNames.isEmpty {
            for (language, name) in localizedNames {
                self.names.append(LocalizedString(language: language, string: name))
            }
        }
        
        if let nameTag = feature.nameTag, !nameTag.isEmpty {
            self.nameTag = nameTag
        }
        
        if let ref = feature.ref, !ref.isEmpty {
            self.ref = ref
        }
        
        // Set geolocation information
        if let geometry = feature.geometry {
            if geometry.type == .point, let point = geometry.point, point.count > 1 {
                latitude = point[1]
                longitude = point[0]
            } else {
                coordinatesJson = geometry.coordinateJSON
            }
            
            if let centroid = geometry.centroid {
                centroidLatitude = centroid[1]
                centroidLongitude = centroid[0]
            } else {
                centroidLatitude = latitude
                centroidLongitude = longitude
            }
        }
        
        // Road specific metadata
        
        roundabout = feature.isRoundabout
        
        // Set additional meta data
        
        if let dynamicURLProp = feature.properties["blind:website:en"] {
            dynamicURL = dynamicURLProp
        }
        
        if let phoneProp = feature.properties["phone"] {
            phone = phoneProp
        }
        
        if let streetNameProp = feature.properties["addr:street"] {
            streetName = streetNameProp
            
            if let streetNumProp = feature.properties["addr:housenumber"] {
                addressLine = streetNumProp + " " + streetNameProp
            }
        }
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
