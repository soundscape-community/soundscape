//
//  TileData.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SSData

/// Point is a class that acts like CLLocationCoordinate2D, but it is hashable. This
/// class is only intended for use in TileData.findIntersections(...), hence the
/// fileprivate access specifier.
private class Point: Hashable {
    // MARK: Properties
    let lat: Double
    let lon: Double
    
    var description: String {
        return String(format: "(%.7f,%.7f)", self.lat, self.lon)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }
    
    // MARK: Initializers
    
    init(latitude: Double, longitude: Double) {
        self.lat = latitude
        self.lon = longitude
    }
    
    // MARK: Static functions
    static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.description == rhs.description
    }
}

/// TileData is a model object for storing all of the POI data belonging to a single
/// vector tile. It stores POIs, roads, and intersections in separate arrays allowing for
/// simple access to the fundamentally different types of OSM data.
final class TileData {
    
    var quadkey = ""
    
    // Array of the pois which have a super category in our super category mapping table
    var pois: [GDASpatialDataResultEntity] = []
    
    // Array of the pois which represent roads
    var roads: [GDASpatialDataResultEntity] = []
    
    // Array of the pois which represent walking paths
    var paths: [GDASpatialDataResultEntity] = []
    
    // Array of the pois which represent intersections
    var intersections: [Intersection] = []
    
    // Temporary set the etag to an empty string - eventually, we will need to actually implement an etag for checking if data has changed
    var etag = ""
    
    // One week TTL for the time being
    var ttl = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)
    
    static var ttlLength: TimeInterval {
        return 7 * 24 * 60 * 60
    }
    
    private var entrances: [String: GeoJsonFeature] = [:]
    
    var tile: VectorTile {
        return VectorTile(quadKey: quadkey)
    }
    
    convenience init(withParsedData json: [String: Any], quadkey: String, etag: String, superCategories: SuperCategories) {
        self.init()
        
        // Get the vector tile info
        self.quadkey = quadkey
        
        // Update the TTL based on the `ttlLength` property
        self.ttl = Date(timeIntervalSinceNow: TileData.ttlLength)
        
        // Store the etag for checking future updates
        self.etag = etag
        
        guard let featuresJson = json["features"] as? [Any] else { return }
        
        for case let featureJson as [String: Any] in featuresJson {
            // Try to parse the feature - the GeoJsonFeature initializer is failable
            guard let feature = GeoJsonFeature(json: featureJson, superCategories: superCategories) else { continue }
            
            // Check if it is a road, intersection, etc.
            if feature.superCategory == .roads {
                if let road = GDASpatialDataResultEntity(feature: feature) { roads.append(road) }
            } else if feature.superCategory == .paths {
                guard let path = GDASpatialDataResultEntity(feature: feature) else { continue }
                paths.append(path)

                if feature.isCrossing,
                   let (crossingStart, crossingEnd) = feature.decomposePathToStartAndEndCrossings(),
                   let crossingID = crossingStart.osmIds.first,
                   let start = GDASpatialDataResultEntity(feature: crossingStart, key: crossingID + "-start"),
                   let end = GDASpatialDataResultEntity(feature: crossingEnd, key: crossingID + "-end") {
                    pois.append(contentsOf: [start, end])
                }
            } else if feature.superCategory == .intersections {
                intersections.append(Intersection(feature: feature))
            } else if feature.superCategory == .entranceLists {
                // Entrance lists must have at least 2 OSD IDs: the owning POI's ID and the entrance POI's ID
                if feature.osmIds.count > 1 {
                    entrances[feature.osmIds[0]] = feature
                }
            } else if let poi = GDASpatialDataResultEntity(feature: feature) {
                pois.append(poi)
            }
        }
        
        // Hook up entrances to their owning POIs
        for poi in pois {
            guard let entrance = entrances[poi.key] else { continue }
            
            let entsub = Array(entrance.osmIds.suffix(from: entrance.osmIds.startIndex + 1))
            do {
                let entdata = try JSONSerialization.data(withJSONObject: entsub)
                poi.entrancesJson = String(data: entdata, encoding: String.Encoding.utf8)
            } catch {
                GDLogAppError("Unable to serialize POI entrance data")
            }
        }
    }
    
    static func getNewExpiration() -> Date {
        return Date(timeIntervalSinceNow: TileData.ttlLength)
    }
    
    static func getExpiredTtl() -> Date {
        return Date(timeIntervalSinceNow: -1)
    }
}

extension TileData {
    convenience init(key: String, metadata: TileMetadata, features: [TileFeature]) throws {
        self.init()
        quadkey = key
        etag = metadata.etag
        ttl = metadata.expiry
        let decoder = JSONDecoder()
        for feature in features {
            switch feature.kind {
            case .poi: pois.append(try decoder.decode(GDASpatialDataResultEntity.self, from: feature.payload))
            case .road: roads.append(try decoder.decode(GDASpatialDataResultEntity.self, from: feature.payload))
            case .path: paths.append(try decoder.decode(GDASpatialDataResultEntity.self, from: feature.payload))
            case .intersection: intersections.append(try decoder.decode(Intersection.self, from: feature.payload))
            }
        }
    }

    func featuresForStorage() throws -> [TileFeature] {
        let encoder = JSONEncoder()
        let groups: [(TileFeature.Kind, [GDASpatialDataResultEntity])] = [(.poi, pois), (.road, roads), (.path, paths)]
        let entities = try groups.flatMap { kind, entities in
            try entities.map { entity in
                TileFeature(key: entity.key, kind: kind, payload: try encoder.encode(entity))
            }
        }
        return try entities + intersections.map { intersection in
            TileFeature(key: intersection.key, kind: .intersection, payload: try encoder.encode(intersection),
                        roadKeys: intersection.roadIds.map(\.id))
        }
    }
}
