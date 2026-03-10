// Copyright (c) Soundscape Community Contributers.

import Foundation

public protocol FilterPredicate {
    func isIncluded(_ poi: any POI) -> Bool
}

public extension FilterPredicate {
    func invert() -> any FilterPredicate {
        CompoundPredicate(notPredicateWithSubpredicate: self)
    }
}
