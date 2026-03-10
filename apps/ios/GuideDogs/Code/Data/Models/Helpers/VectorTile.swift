//
//  VectorTile.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSDataContracts
import SSGeo

typealias VectorTile = SSDataContracts.VectorTile

extension SSDataContracts.VectorTile {
    nonisolated static func tilesForRegion(_ location: CLLocation, radius: CLLocationDistance, zoom zoomLevel: UInt) -> [SSDataContracts.VectorTile] {
        tilesForRegion(location.ssGeoLocation, radiusMeters: radius, zoom: zoomLevel)
    }

    nonisolated static func tileForLocation(_ location: CLLocation, zoom zoomLevel: UInt) -> SSDataContracts.VectorTile {
        tileForLocation(location.ssGeoLocation, zoom: zoomLevel)
    }
}
