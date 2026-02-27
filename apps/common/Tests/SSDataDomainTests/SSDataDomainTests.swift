// Copyright (c) Soundscape Community Contributers.

import Foundation
import Testing

@testable import SSDataDomain

struct SSDataDomainTests {
    @Test
    func routeDefaultsAreStable() {
        let route = Route()

        #expect(route.id.isEmpty == false)
        #expect(route.name.isEmpty)
        #expect(route.routeDescription == nil)
        #expect(route.waypoints.isEmpty)
        #expect(route.firstWaypointLatitude == nil)
        #expect(route.firstWaypointLongitude == nil)
        #expect(route.isNew)
    }

    @Test
    func routePreservesExplicitValues() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let waypoint = RouteWaypoint(index: 2, markerId: "marker-1", importedReferenceEntity: nil)
        let route = Route(
            id: "route-1",
            name: "Test Route",
            routeDescription: "desc",
            waypoints: [waypoint],
            firstWaypointLatitude: 47.0,
            firstWaypointLongitude: -122.0,
            isNew: false,
            createdDate: now,
            lastUpdatedDate: now,
            lastSelectedDate: now,
            reversedRouteId: "route-2"
        )

        #expect(route.id == "route-1")
        #expect(route.name == "Test Route")
        #expect(route.routeDescription == "desc")
        #expect(route.waypoints.count == 1)
        #expect(route.firstWaypointLatitude == 47.0)
        #expect(route.firstWaypointLongitude == -122.0)
        #expect(route.isNew == false)
        #expect(route.reversedRouteId == "route-2")
    }

    @Test
    func waypointOrderingSortsByIndex() {
        let ordered = [
            RouteWaypoint(index: 3, markerId: "3", importedReferenceEntity: nil),
            RouteWaypoint(index: 1, markerId: "1", importedReferenceEntity: nil),
            RouteWaypoint(index: 2, markerId: "2", importedReferenceEntity: nil),
        ].ordered

        #expect(ordered.map(\.index) == [1, 2, 3])
    }

    @Test
    func referenceEntityCoordinateAccessorsMatchCoordinate() {
        let entity = ReferenceEntity(
            id: "marker-id",
            entityKey: "entity-key",
            lastUpdatedDate: nil,
            lastSelectedDate: nil,
            isNew: true,
            isTemp: false,
            coordinate: .init(latitude: 47.6205, longitude: -122.3493),
            nickname: "nickname",
            estimatedAddress: "address",
            annotation: "annotation"
        )

        #expect(entity.latitude == entity.coordinate.latitude)
        #expect(entity.longitude == entity.coordinate.longitude)
    }
}
