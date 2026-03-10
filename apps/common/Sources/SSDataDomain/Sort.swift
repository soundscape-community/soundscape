// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct Sort {
    public static func distance(origin: SSGeoLocation, useEntranceIfAvailable: Bool = false) -> any SortPredicate {
        DistancePredicate(origin: origin, useEntranceIfAvailable: useEntranceIfAvailable)
    }

    public static func lastSelected() -> any SortPredicate {
        LastSelectedPredicate()
    }
}
