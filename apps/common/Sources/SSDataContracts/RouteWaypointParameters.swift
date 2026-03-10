// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct RouteWaypointParameters: Codable, Sendable {
    public let index: Int
    public let markerId: String
    public let marker: MarkerParameters?

    public init(index: Int, markerId: String, marker: MarkerParameters?) {
        self.index = index
        self.markerId = markerId
        self.marker = marker
    }
}
