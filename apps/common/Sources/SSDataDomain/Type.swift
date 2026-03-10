// Copyright (c) Soundscape Community Contributers.

import Foundation

public protocol Type: Sendable {
    func matches(poi: any POI) -> Bool
}
