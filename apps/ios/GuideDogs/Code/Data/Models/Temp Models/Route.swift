//
//  Route.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import CoreLocation
import SSDataDomain

typealias Route = SSDataDomain.Route

@MainActor
extension Route {
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

    /**
     * Initializes a route for which all associated markers have been added to the Realm database
     *
     * - Parameters:
     *     - name: Name of the route, required
     *     - description: Description of the route, optional
     *     - waypoints: Array of waypoints - All waypoints are markers that exist in the Realm database
     */
    init(name: String, description: String?, waypoints: [RouteWaypoint]) {
        self.init(name: name,
                  description: description,
                  waypoints: waypoints,
                  firstWaypointCoordinate: nil)
    }

    init(name: String, description: String?, waypoints: [RouteWaypoint], firstWaypointCoordinate: CLLocationCoordinate2D?) {
        self.init(name: name,
                  routeDescription: description,
                  waypoints: waypoints)

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
    init(from parameters: RouteParameters) {
        self.init(from: parameters, firstWaypointCoordinate: nil)
    }

    init(from parameters: RouteParameters, firstWaypointCoordinate: CLLocationCoordinate2D?) {
        let parameterWaypoints = parameters.waypoints.map { RouteWaypoint(from: $0) }
        let resolvedFirstWaypointCoordinate = firstWaypointCoordinate
            ?? Self.firstWaypointCoordinate(for: parameterWaypoints)

        self.init(id: parameters.id,
                  name: parameters.name,
                  routeDescription: parameters.routeDescription,
                  waypoints: parameterWaypoints,
                  firstWaypointLatitude: resolvedFirstWaypointCoordinate?.latitude,
                  firstWaypointLongitude: resolvedFirstWaypointCoordinate?.longitude,
                  isNew: true,
                  createdDate: parameters.createdDate ?? Date(),
                  lastUpdatedDate: parameters.lastUpdatedDate ?? Date(),
                  lastSelectedDate: parameters.lastSelectedDate ?? Date(),
                  reversedRouteId: nil)
    }
}
