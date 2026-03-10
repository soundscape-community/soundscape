//
//  Array+POI.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSGeo

@MainActor
extension Array where Element == POI {
    typealias Quadrant = [CompassDirection: [POI]]

    func sorted(byDistanceFrom location: CLLocation) -> [POI] {
        sorted(byDistanceFrom: location.ssGeoLocation)
    }

    func quadrants(_ includedQuadrants: [CompassDirection] = CompassDirection.allDirections, location: CLLocation, heading: CLLocationDirection, categories: [SuperCategory], maxLengthPerQuadrant: Int) -> Quadrant {
        let quadrants = SpatialDataView.getQuadrants(heading: heading)
        let sortPredicate = Sort.distance(origin: location)
        let categoryFilterPredicate = Filter.superCategories(orExpected: categories)

        let queues: [CompassDirection: POIQueue] = includedQuadrants.reduce(into: [:]) { dict, direction in
            dict[direction] = POIQueue(maxItems: maxLengthPerQuadrant + 10, sort: sortPredicate, filter: categoryFilterPredicate)
        }

        for poi in self {
            let dir = CompassDirection.from(bearing: poi.bearingToClosestLocation(from: location), quadrants: quadrants)
            queues[dir]?.insert(poi)
        }

        let locationFilterPredicate = Filter.location(expected: location).invert()

        return queues.reduce(into: [:]) { partialResult, kvp in
            partialResult[kvp.key] = kvp.value.pois.filtered(by: locationFilterPredicate, maxLength: maxLengthPerQuadrant).map { $0 }
        }
    }
}
