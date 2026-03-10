// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct LastSelectedPredicate: SortPredicate {
    public init() {}

    public func areInIncreasingOrder(_ lhs: any POI, _ rhs: any POI) -> Bool {
        guard let lhs = lhs as? any SelectablePOI, let rhs = rhs as? any SelectablePOI else {
            return true
        }

        if let lhsLastSelectedDate = lhs.lastSelectedDate, let rhsLastSelectedDate = rhs.lastSelectedDate {
            return lhsLastSelectedDate > rhsLastSelectedDate
        }

        return lhs.lastSelectedDate != nil
    }
}
