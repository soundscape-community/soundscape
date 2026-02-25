//
//  RealmRouteWaypoint.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import RealmSwift

extension RouteWaypoint {
    init(realmWaypoint: RealmRouteWaypoint) {
        self.init()
        index = realmWaypoint.index
        markerId = realmWaypoint.markerId
    }

    var realmObject: RealmRouteWaypoint {
        RealmRouteWaypoint(waypoint: self)
    }
}

@objc(RouteWaypoint)
class RealmRouteWaypoint: EmbeddedObject {
    // MARK: Properties

    @Persisted var index: Int = -1
    @Persisted var markerId: String = ""

    convenience init(waypoint: RouteWaypoint) {
        self.init()
        index = waypoint.index
        markerId = waypoint.markerId
    }

    var domainModel: RouteWaypoint {
        RouteWaypoint(realmWaypoint: self)
    }
}

extension List where Element == RealmRouteWaypoint {
    var ordered: [RealmRouteWaypoint] {
        sorted(by: { $0.index < $1.index })
    }
}
