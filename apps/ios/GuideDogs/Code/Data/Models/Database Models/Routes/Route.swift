//
//  Route.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SSData
import CoreLocation

extension Notification.Name {
    static let routeAdded = Notification.Name("GDARouteAdded")
    static let routeUpdated = Notification.Name("GDARouteUpdated")
    static let routeDeleted = Notification.Name("GDARouteDeleted")
}

/*
 A route is an ordered collection of markers. Additional metadata for
 routes include name, description and various properties which track
 route usage (e.g., `createdDate`, `lastUpdatedDate`, `lastSelectedDate`)
 */
final class Route: Identifiable {
    
    // MARK: Constants
    
    struct Keys {
        static let id = "GDARouteID"
    }
    
    // MARK: Properties
    
    // Primary Key
    var id: String = UUID().uuidString
    var name: String = ""
    var routeDescription: String?
    var waypoints: [RouteWaypoint] = []
    // Save the location of the first waypoint to support fast queries
    // for nearby routes
    var firstWaypointLatitude: CLLocationDegrees?
    var firstWaypointLongitude: CLLocationDegrees?
    var isNew: Bool = true
    var createdDate: Date = Date()
    var lastUpdatedDate: Date = Date()
    // `lastSelectedDate` is updated when the user selects an action
    // (`RouteAction` - start, share, etc.) for the route
    var lastSelectedDate: Date = Date()
    var reversedRouteId: String?
    
    var firstWaypointLocation: CLLocation? {
        guard let latitude = firstWaypointLatitude, let longitude = firstWaypointLongitude else {
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        guard coordinate.isValidLocationCoordinate else {
            return nil
        }
        
        return CLLocation(coordinate)
    }
    
    var isActive: Bool {
        guard let routeGuidance = AppContext.shared.eventProcessor.activeBehavior as? RouteGuidance else {
            return false
        }
        
        guard case let .database(activeID) = routeGuidance.content.source else {
            return false
        }
        
        return activeID == self.id
    }
    
    // MARK: Initialization
    
    /**
     * Initializes a route for which all associated markers have been added to the user database
     *
     * - Parameters:
     *     - name: Name of the route, required
     *     - description: Description of the route, optional
     *     - waypoints: Array of waypoints - All waypoints are markers that exist in the user database
     */
    convenience init(name: String, description: String?, waypoints: [RouteWaypoint]) {
        self.init()
        
        self.name = name
        self.routeDescription = description
        
        // Append waypoints
        waypoints.forEach({ self.waypoints.append($0) })
        
        if let first = waypoints.ordered.first, let marker = first.asLocationDetail {
            firstWaypointLatitude = marker.location.coordinate.latitude
            firstWaypointLongitude = marker.location.coordinate.longitude
        }
    }
    
    convenience init(saved: SavedRoute) {
        self.init()
        id = saved.id
        name = saved.name
        routeDescription = saved.routeDescription
        waypoints = saved.waypoints.map { RouteWaypoint(stored: $0) }
        isNew = saved.isNew
        createdDate = saved.createdDate
        lastUpdatedDate = saved.lastUpdatedDate
        lastSelectedDate = saved.lastSelectedDate
        reversedRouteId = saved.reversedRouteId
        if let first = saved.waypoints.first, let marker = SpatialDataCache.referenceEntityByKey(first.markerId) {
            firstWaypointLatitude = marker.latitude
            firstWaypointLongitude = marker.longitude
        }
    }

    var saved: SavedRoute {
        SavedRoute(id: id, name: name, routeDescription: routeDescription, waypoints: waypoints.map(\.stored),
                   isNew: isNew, createdDate: createdDate, lastUpdatedDate: lastUpdatedDate,
                   lastSelectedDate: lastSelectedDate, reversedRouteId: reversedRouteId)
    }

}
