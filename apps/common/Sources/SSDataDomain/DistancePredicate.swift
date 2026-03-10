// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct DistancePredicate: SortPredicate {
    public let origin: SSGeoLocation
    public let useEntranceIfAvailable: Bool

    public init(origin: SSGeoLocation, useEntranceIfAvailable: Bool = false) {
        self.origin = origin
        self.useEntranceIfAvailable = useEntranceIfAvailable
    }

    public func areInIncreasingOrder(_ lhs: any POI, _ rhs: any POI) -> Bool {
        let lhsDistance = lhs.distanceToClosestLocation(from: origin, useEntranceIfAvailable: useEntranceIfAvailable)
        let rhsDistance = rhs.distanceToClosestLocation(from: origin, useEntranceIfAvailable: useEntranceIfAvailable)

        return lhsDistance < rhsDistance
    }
}
