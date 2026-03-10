// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct TypePredicate: FilterPredicate {
    public let expectedType: any Type

    public init(expected: any Type) {
        expectedType = expected
    }

    public func isIncluded(_ poi: any POI) -> Bool {
        expectedType.matches(poi: poi)
    }
}
