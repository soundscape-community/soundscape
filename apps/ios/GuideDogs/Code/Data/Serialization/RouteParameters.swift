//
//  RouteParameters.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SSDataContracts
import SSDataDomain

typealias RouteParameters = SSDataContracts.RouteParameters

extension SSDataContracts.RouteParameters {
    @MainActor
    init?(route: SSDataDomain.Route, context: Context) {
        let id = route.id
        let name = route.name
        let routeDescription = route.routeDescription
        let waypoints = route.waypoints.map { RouteWaypointParameters(waypoint: $0) }
        let createdDate = context == .backup ? route.createdDate : nil
        let lastUpdatedDate = context == .backup ? route.lastUpdatedDate : nil
        let lastSelectedDate = context == .backup ? route.lastSelectedDate : nil

        guard context == .backup || waypoints.contains(where: { $0.marker == nil }) == false else {
            return nil
        }

        self.init(id: id,
                  name: name,
                  routeDescription: routeDescription,
                  waypoints: waypoints,
                  createdDate: createdDate,
                  lastUpdatedDate: lastUpdatedDate,
                  lastSelectedDate: lastSelectedDate)
    }
}
