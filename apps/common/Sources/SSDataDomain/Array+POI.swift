// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public extension Array where Element == any POI {
    func sorted(by sortPredicate: any SortPredicate, filteredBy filterPredicate: (any FilterPredicate)? = nil, maxLength: Int) -> [any POI] {
        let queue = POIQueue(maxItems: maxLength, sort: sortPredicate, filter: filterPredicate)
        queue.insert(self)
        return queue.pois
    }

    func sorted(byDistanceFrom location: SSGeoLocation, useEntranceIfAvailable: Bool = false) -> [any POI] {
        let sortPredicate = Sort.distance(origin: location, useEntranceIfAvailable: useEntranceIfAvailable)
        return sorted(by: sortPredicate, maxLength: count)
    }

    func filtered(by filterPredicate: any FilterPredicate, maxLength: Int? = nil) -> [any POI] {
        var pois: [any POI] = []

        for poi in self {
            if let maxLength = maxLength {
                guard pois.count < maxLength else {
                    return pois
                }
            }

            guard filterPredicate.isIncluded(poi) else {
                continue
            }

            pois.append(poi)
        }

        return pois
    }
}
