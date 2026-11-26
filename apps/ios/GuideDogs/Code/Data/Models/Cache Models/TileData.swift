//
//  TileData.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SSData

struct TileData {
    let pois: [GDASpatialDataResultEntity]
    let roads: [GDASpatialDataResultEntity]
    let intersections: [Intersection]

    init(parsed: ParsedTile) {
        pois = parsed.pois.map(GDASpatialDataResultEntity.init(data:))
        roads = parsed.roads.map(GDASpatialDataResultEntity.init(data:))
        intersections = parsed.intersections.map(Intersection.init(data:))
    }
}
