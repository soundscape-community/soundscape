//
//  Route.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import CoreLocation

/*
 A route is an ordered collection of markers. Additional metadata for
 routes include name, description and various properties which track
 route usage (e.g., `createdDate`, `lastUpdatedDate`, `lastSelectedDate`)
 */
struct Route: Identifiable {

    // MARK: Constants

    struct Keys {
        static let id = "GDARouteID"
    }

    // MARK: Properties

    var id: String = UUID().uuidString
    var name: String = ""
    // `description` is a reserved name in multiple contexts, so prefix for consistency
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

    // MARK: Initialization

    init() {}

    /**
     * Initializes a route for which all associated markers have been added to the Realm database
     *
     * - Parameters:
     *     - name: Name of the route, required
     *     - description: Description of the route, optional
     *     - waypoints: Array of waypoints - All waypoints are markers that exist in the Realm databse
     */
    @MainActor
    init(name: String, description: String?, waypoints: [RouteWaypoint]) {
        self.init(name: name,
                  description: description,
                  waypoints: waypoints,
                  firstWaypointCoordinate: nil)
    }

    @MainActor
    init(name: String, description: String?, waypoints: [RouteWaypoint], firstWaypointCoordinate: CLLocationCoordinate2D?) {
        self.name = name
        self.routeDescription = description
        self.waypoints = waypoints

        if let resolvedFirstWaypointCoordinate = firstWaypointCoordinate
            ?? Self.firstWaypointCoordinate(for: waypoints) {
            firstWaypointLatitude = resolvedFirstWaypointCoordinate.latitude
            firstWaypointLongitude = resolvedFirstWaypointCoordinate.longitude
        }
    }

    /**
     Only use this initializer when you made sure all the route waypoints (marker)
     were already imported to the database.
     */
    @MainActor
    init(from parameters: RouteParameters) {
        self.init(from: parameters, firstWaypointCoordinate: nil)
    }

    @MainActor
    init(from parameters: RouteParameters, firstWaypointCoordinate: CLLocationCoordinate2D?) {
        // Required Parameters
        id = parameters.id
        name = parameters.name
        routeDescription = parameters.routeDescription

        // Append waypoints
        let parameterWaypoints = parameters.waypoints.map { RouteWaypoint(from: $0) }
        waypoints = parameterWaypoints

        if let resolvedFirstWaypointCoordinate = firstWaypointCoordinate
            ?? Self.firstWaypointCoordinate(for: parameterWaypoints) {
            firstWaypointLatitude = resolvedFirstWaypointCoordinate.latitude
            firstWaypointLongitude = resolvedFirstWaypointCoordinate.longitude
        }

        // Optional Parameters

        if let parameterCreatedDate = parameters.createdDate {
            createdDate = parameterCreatedDate
        }

        if let parameterLastUpdatedDate = parameters.lastUpdatedDate {
            lastUpdatedDate = parameterLastUpdatedDate
        }

        if let parameterLastSelectedDate = parameters.lastSelectedDate {
            lastSelectedDate = parameterLastSelectedDate
        }
    }
}
