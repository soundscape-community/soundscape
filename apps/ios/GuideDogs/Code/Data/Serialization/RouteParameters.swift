//
//  RouteParamters.swift
//  SoundscapeUnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

/*
 Supports serialization for sharing a saved route
 */
struct RouteParameters: Codable {
    
    // MARK: Properties
    
    let id: String
    let name: String
    let routeDescription: String?
    let waypoints: [RouteWaypointParameters]
    // Older documents may include these values. Shared routes omit them.
    let createdDate: Date?
    let lastUpdatedDate: Date?
    let lastSelectedDate: Date?
    
    // MARK: Initialization
    
    init(id: String, name: String, routeDescription: String?, waypoints: [RouteWaypointParameters], createdDate: Date?, lastUpdatedDate: Date?, lastSelectedDate: Date?) {
        self.id = id
        self.name = name
        self.routeDescription = routeDescription
        self.waypoints = waypoints
        self.createdDate = createdDate
        self.lastUpdatedDate = lastUpdatedDate
        self.lastSelectedDate = lastSelectedDate
    }
    
    init?(route: Route) {
        let waypoints = route.waypoints.ordered.map(RouteWaypointParameters.init(waypoint:))
        guard waypoints.allSatisfy({ $0.marker != nil }) else { return nil }
        self.init(id: route.id, name: route.name, routeDescription: route.routeDescription,
                  waypoints: waypoints, createdDate: nil, lastUpdatedDate: nil, lastSelectedDate: nil)
    }
}
