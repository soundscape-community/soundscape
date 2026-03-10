// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum SecondaryType: Sendable, Type {
    case transitStop
    case food
    case park
    case bank
    case grocery

    public func matches(poi: any POI) -> Bool {
        guard let typeable = poi as? any Typeable else {
            return false
        }

        return typeable.isOfType(self)
    }
}
