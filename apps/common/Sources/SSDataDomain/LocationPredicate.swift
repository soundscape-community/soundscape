// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct LocationPredicate: FilterPredicate {
    public let expectedLocation: SSGeoLocation

    public init(expected: SSGeoLocation) {
        expectedLocation = expected
    }

    public func isIncluded(_ poi: any POI) -> Bool {
        poi.contains(location: expectedLocation.coordinate)
    }
}
