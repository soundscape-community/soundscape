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
    init?(route: SSDataDomain.Route, context: Context) async {
        let id = route.id
        let name = route.name
        let routeDescription = route.routeDescription
        var waypoints: [RouteWaypointParameters] = []
        waypoints.reserveCapacity(route.waypoints.count)

        for waypoint in route.waypoints {
            waypoints.append(await RouteWaypointParameters(waypoint: waypoint))
        }

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

    @MainActor
    init?(routeDetail: RouteDetail, context: Context) {
        let waypoints = routeDetail.waypoints.enumerated().compactMap { index, detail -> RouteWaypointParameters? in
            guard let markerId = detail.markerId else {
                return nil
            }

            switch context {
            case .backup:
                return RouteWaypointParameters(index: index, markerId: markerId, marker: nil)
            case .share:
                guard let marker = MarkerParameters(location: detail) else {
                    return nil
                }

                return RouteWaypointParameters(index: index, markerId: markerId, marker: marker)
            }
        }

        guard waypoints.count == routeDetail.waypoints.count else {
            return nil
        }

        let routeDescription = routeDetail.description
        self.init(id: routeDetail.id,
                  name: routeDetail.displayName,
                  routeDescription: routeDescription,
                  waypoints: waypoints,
                  createdDate: nil,
                  lastUpdatedDate: nil,
                  lastSelectedDate: nil)
    }
}
