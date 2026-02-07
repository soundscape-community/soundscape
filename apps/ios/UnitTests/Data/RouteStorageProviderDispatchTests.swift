//
//  RouteStorageProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class RouteStorageProviderDispatchTests: XCTestCase {
    final class MockRouteSpatialDataStore: RouteSpatialDataStore {
        var referenceEntitiesByKey: [String: ReferenceEntity] = [:]
        var routesToReturn: [Route] = []
        var routesContainingToReturn: [String: [Route]] = [:]

        private(set) var referenceEntityByKeyCallKeys: [String] = []
        private(set) var routesCallCount = 0
        private(set) var routesContainingCallKeys: [String] = []

        func referenceEntityByKey(_ key: String) -> ReferenceEntity? {
            referenceEntityByKeyCallKeys.append(key)
            return referenceEntitiesByKey[key]
        }

        func routes() -> [Route] {
            routesCallCount += 1
            return routesToReturn
        }

        func routesContaining(markerId: String) -> [Route] {
            routesContainingCallKeys.append(markerId)
            return routesContainingToReturn[markerId] ?? []
        }
    }

    override func tearDownWithError() throws {
        RouteSpatialDataStoreRegistry.resetForTesting()
        try clearAllRoutes()
    }

    func testObjectKeysDistanceUsesInjectedSpatialStoreForMarkerLookup() throws {
        let route = try createPersistedRoute(name: "DistanceTestRoute")
        let markerID = route.waypoints.ordered.first?.markerId
        XCTAssertNotNil(markerID)

        let store = MockRouteSpatialDataStore()
        RouteSpatialDataStoreRegistry.configure(with: store)

        let keys = Route.objectKeys(sortedBy: .distance)

        XCTAssertTrue(keys.contains(route.id))
        XCTAssertEqual(store.referenceEntityByKeyCallKeys.first, markerID)
    }

    func testRemoveWaypointFromAllRoutesUsesInjectedSpatialStoreLookup() throws {
        let store = MockRouteSpatialDataStore()
        store.routesContainingToReturn["marker-id"] = []
        RouteSpatialDataStoreRegistry.configure(with: store)

        try Route.removeWaypointFromAllRoutes(markerId: "marker-id")

        XCTAssertEqual(store.routesContainingCallKeys, ["marker-id"])
    }

    func testDeleteAllUsesInjectedSpatialStoreRoutesList() throws {
        let store = MockRouteSpatialDataStore()
        store.routesToReturn = []
        RouteSpatialDataStoreRegistry.configure(with: store)

        try Route.deleteAll()

        XCTAssertEqual(store.routesCallCount, 1)
    }

    private func createPersistedRoute(name: String) throws -> Route {
        let waypointLocation = CLLocation(latitude: 47.6205, longitude: -122.3493)
        let imported = ImportedLocationDetail(nickname: "Waypoint", annotation: "Test waypoint")
        let waypointDetail = LocationDetail(location: waypointLocation, imported: imported, telemetryContext: nil)
        let waypoint = RouteWaypoint(index: 0,
                                     markerId: "route-storage-marker-\(UUID().uuidString)",
                                     importedLocationDetail: waypointDetail)
        let route = Route(name: name, description: nil, waypoints: [waypoint])

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(route, update: .modified)
        }

        return route
    }

    private func clearAllRoutes() throws {
        let database = try RealmHelper.getDatabaseRealm()
        let routes = database.objects(Route.self)

        guard !routes.isEmpty else {
            return
        }

        try database.write {
            database.delete(routes)
        }
    }
}
