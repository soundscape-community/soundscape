//
//  MapFeature.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

public struct LocalizedMapName: Codable, Sendable {
    public let language: String
    public let string: String
}

public struct MapFeature: Codable, Sendable {
    public let key: String
    public private(set) var name: String
    public private(set) var names: [LocalizedMapName] = []
    public private(set) var nameTag = ""
    public private(set) var ref = ""
    public private(set) var superCategory = SuperCategory.undefined.rawValue
    public private(set) var amenity = ""
    public private(set) var phone: String?
    public private(set) var addressLine: String?
    public private(set) var streetName: String?
    public var roundabout = false
    public private(set) var coordinatesJson: String?
    public internal(set) var entranceIDs: [String] = []
    public private(set) var dynamicURL: String?
    public private(set) var latitude: CLLocationDegrees
    public private(set) var longitude: CLLocationDegrees
    public private(set) var centroidLatitude: CLLocationDegrees
    public private(set) var centroidLongitude: CLLocationDegrees

    public init(key: String, name: String, addressLine: String?, streetName: String? = nil,
                latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.key = key
        self.name = name
        self.addressLine = addressLine
        self.streetName = streetName
        self.latitude = latitude
        self.longitude = longitude
        centroidLatitude = latitude
        centroidLongitude = longitude
    }

    init?(feature: GeoJsonFeature, key: String? = nil) {
        guard let key = key ?? feature.osmIds.first, !key.isEmpty else { return nil }
        self.init(key: key, name: feature.name ?? "", addressLine: nil, latitude: 0, longitude: 0)

        superCategory = feature.superCategory.rawValue
        amenity = feature.value

        if let localizedNames = feature.names, !localizedNames.isEmpty {
            for (language, name) in localizedNames {
                self.names.append(LocalizedMapName(language: language, string: name))
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
}

public struct MapIntersection: Codable, Sendable {
    public var key: String
    public var roadIDs: [String]
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees

    public init(key: String = "", roadIDs: [String] = [], latitude: CLLocationDegrees = 0, longitude: CLLocationDegrees = 0) {
        self.key = key
        self.roadIDs = roadIDs
        self.latitude = latitude
        self.longitude = longitude
    }

    init(feature: GeoJsonFeature) {
        let latitude = feature.geometry?.point?[1] ?? 0
        let longitude = feature.geometry?.point?[0] ?? 0
        self.init(key: feature.osmIds.joined() + String(latitude) + String(longitude),
                  roadIDs: feature.osmIds, latitude: latitude, longitude: longitude)
    }
}
