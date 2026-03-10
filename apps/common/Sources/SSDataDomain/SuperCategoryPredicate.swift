// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct SuperCategoryPredicate: FilterPredicate {
    public let expectedSuperCategory: SuperCategory

    public init(expected: SuperCategory) {
        expectedSuperCategory = expected
    }

    public func isIncluded(_ poi: any POI) -> Bool {
        guard let category = SuperCategory(rawValue: poi.superCategory) else {
            return false
        }

        return category == expectedSuperCategory
    }
}
