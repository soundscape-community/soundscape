// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation

public struct ParsedTile: Sendable {
    public let quadkey: String
    public let metadata: TileMetadata
    public private(set) var pois: [MapFeature] = []
    public private(set) var roads: [MapFeature] = []
    public private(set) var paths: [MapFeature] = []
    public private(set) var intersections: [MapIntersection] = []

    public init(json: [String: Any], quadkey: String, etag: String, categories: SuperCategories,
                intersectionName: String, entranceListName: String, now: Date = Date()) {
        self.quadkey = quadkey
        metadata = TileMetadata(etag: etag, expiry: Self.expiry(after: now))

        guard let values = json["features"] as? [Any] else { return }
        var entrances: [String: [String]] = [:]

        for case let value as [String: Any] in values {
            guard let feature = GeoJsonFeature(json: value, superCategories: categories,
                                               intersectionName: intersectionName, entranceListName: entranceListName) else { continue }
            switch feature.superCategory {
            case .roads:
                if let road = MapFeature(feature: feature) { roads.append(road) }
            case .paths:
                guard let path = MapFeature(feature: feature) else { continue }
                paths.append(path)

                if feature.isCrossing,
                   let (crossingStart, crossingEnd) = feature.decomposePathToStartAndEndCrossings(),
                   let id = crossingStart.osmIds.first,
                   let start = MapFeature(feature: crossingStart, key: id + "-start"),
                   let end = MapFeature(feature: crossingEnd, key: id + "-end") {
                    pois.append(contentsOf: [start, end])
                }
            case .intersections:
                intersections.append(MapIntersection(feature: feature))
            case .entranceLists:
                if feature.osmIds.count > 1, let owner = feature.osmIds.first {
                    entrances[owner] = Array(feature.osmIds.dropFirst())
                }
            default:
                if let poi = MapFeature(feature: feature) { pois.append(poi) }
            }
        }

        for index in pois.indices {
            if let ids = entrances[pois[index].key] { pois[index].entranceIDs = ids }
        }
    }

    public init(quadkey: String, metadata: TileMetadata, features: [TileFeature]) throws {
        self.quadkey = quadkey
        self.metadata = metadata
        let decoder = JSONDecoder()
        for feature in features {
            switch feature.kind {
            case .poi: pois.append(try decoder.decode(MapFeature.self, from: feature.payload))
            case .road: roads.append(try decoder.decode(MapFeature.self, from: feature.payload))
            case .path: paths.append(try decoder.decode(MapFeature.self, from: feature.payload))
            case .intersection: intersections.append(try decoder.decode(MapIntersection.self, from: feature.payload))
            }
        }
    }

    public static func expiry(after date: Date = Date()) -> Date {
        date.addingTimeInterval(7 * 24 * 60 * 60)
    }

    public func featuresForStorage() throws -> [TileFeature] {
        let encoder = JSONEncoder()
        let groups: [(TileFeature.Kind, [MapFeature])] = [(.poi, pois), (.road, roads), (.path, paths)]
        let entities = try groups.flatMap { kind, features in
            try features.map { TileFeature(key: $0.key, kind: kind, payload: try encoder.encode($0)) }
        }
        return try entities + intersections.map {
            TileFeature(key: $0.key, kind: .intersection, payload: try encoder.encode($0), roadKeys: $0.roadIDs)
        }
    }
}

public extension TileFeature {
    func mapFeature() throws -> MapFeature {
        try JSONDecoder().decode(MapFeature.self, from: payload)
    }

    func mapIntersection() throws -> MapIntersection {
        try JSONDecoder().decode(MapIntersection.self, from: payload)
    }
}
