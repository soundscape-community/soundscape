// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct RouteParameters: Codable, Sendable {
    public enum Context: Sendable {
        case backup
        case share
    }

    public let id: String
    public let name: String
    public let routeDescription: String?
    public let waypoints: [RouteWaypointParameters]
    public let createdDate: Date?
    public let lastUpdatedDate: Date?
    public let lastSelectedDate: Date?

    public init(
        id: String,
        name: String,
        routeDescription: String?,
        waypoints: [RouteWaypointParameters],
        createdDate: Date?,
        lastUpdatedDate: Date?,
        lastSelectedDate: Date?
    ) {
        self.id = id
        self.name = name
        self.routeDescription = routeDescription
        self.waypoints = waypoints
        self.createdDate = createdDate
        self.lastUpdatedDate = lastUpdatedDate
        self.lastSelectedDate = lastSelectedDate
    }
}
