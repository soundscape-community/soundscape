//
//  RouteWaypointParameters.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SSDataContracts
import SSDataDomain

typealias RouteWaypointParameters = SSDataContracts.RouteWaypointParameters

extension SSDataContracts.RouteWaypointParameters {
    @MainActor
    init(waypoint: SSDataDomain.RouteWaypoint) async {
        self.init(index: waypoint.index,
                  markerId: waypoint.markerId,
                  marker: await MarkerParameters(markerId: waypoint.markerId))
    }
}
