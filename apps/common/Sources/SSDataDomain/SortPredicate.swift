// Copyright (c) Soundscape Community Contributers.

import Foundation

public protocol SortPredicate {
    func areInIncreasingOrder(_ lhs: any POI, _ rhs: any POI) -> Bool
}
