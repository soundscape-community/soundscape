// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct Route: Identifiable, Sendable {
    public struct Keys {
        public static let id = "GDARouteID"
    }

    public var id: String = UUID().uuidString
    public var name: String = ""
    public var routeDescription: String?
    public var waypoints: [RouteWaypoint] = []
    public var firstWaypointLatitude: Double?
    public var firstWaypointLongitude: Double?
    public var isNew: Bool = true
    public var createdDate: Date = Date()
    public var lastUpdatedDate: Date = Date()
    public var lastSelectedDate: Date = Date()
    public var reversedRouteId: String?

    public init() {}

    public init(
        id: String = UUID().uuidString,
        name: String,
        routeDescription: String?,
        waypoints: [RouteWaypoint],
        firstWaypointLatitude: Double? = nil,
        firstWaypointLongitude: Double? = nil,
        isNew: Bool = true,
        createdDate: Date = Date(),
        lastUpdatedDate: Date = Date(),
        lastSelectedDate: Date = Date(),
        reversedRouteId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.routeDescription = routeDescription
        self.waypoints = waypoints
        self.firstWaypointLatitude = firstWaypointLatitude
        self.firstWaypointLongitude = firstWaypointLongitude
        self.isNew = isNew
        self.createdDate = createdDate
        self.lastUpdatedDate = lastUpdatedDate
        self.lastSelectedDate = lastSelectedDate
        self.reversedRouteId = reversedRouteId
    }
}
