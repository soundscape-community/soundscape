// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum PrimaryType: String, CaseIterable, Sendable, Type {
    case transit
    case food
    case park
    case bank
    case grocery
    case navilens

    public func matches(poi: any POI) -> Bool {
        guard let typeable = poi as? any Typeable else {
            return false
        }

        return typeable.isOfType(self)
    }
}
