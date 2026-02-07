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
    final class MockSpatialDataStore: SpatialDataStore {
        var referenceEntitiesByKey: [String: ReferenceEntity] = [:]
        var referenceEntitiesByEntityKey: [String: ReferenceEntity] = [:]
        var referenceEntitiesByLocation: [String: ReferenceEntity] = [:]
        var referenceEntitiesNearByLocation: [String: [ReferenceEntity]] = [:]
        var referenceEntitiesToReturn: [ReferenceEntity] = []
        var searchResultsByKey: [String: POI] = [:]
        var addedReferenceEntityID = "mock-added-reference-entity-id"
        var routesToReturn: [Route] = []
        var routesByKey: [String: Route] = [:]
        var routesContainingToReturn: [String: [Route]] = [:]

        private(set) var referenceEntityByKeyCallKeys: [String] = []
        private(set) var referenceEntityByEntityKeyCallKeys: [String] = []
        private(set) var referenceEntityByLocationCallKeys: [String] = []
        private(set) var referenceEntitiesNearCallKeys: [String] = []
        private(set) var referenceEntitiesCallCount = 0
        private(set) var searchByKeyCallKeys: [String] = []
        private(set) var addReferenceEntityCallCount = 0
        private(set) var routesCallCount = 0
        private(set) var routeByKeyCallKeys: [String] = []
        private(set) var routesContainingCallKeys: [String] = []

        func referenceEntityByKey(_ key: String) -> ReferenceEntity? {
            referenceEntityByKeyCallKeys.append(key)
            return referenceEntitiesByKey[key]
        }

        func referenceEntityByEntityKey(_ key: String) -> ReferenceEntity? {
            referenceEntityByEntityKeyCallKeys.append(key)
            return referenceEntitiesByEntityKey[key]
        }

        func referenceEntityByLocation(_ coordinate: CLLocationCoordinate2D) -> ReferenceEntity? {
            let key = locationKey(for: coordinate)
            referenceEntityByLocationCallKeys.append(key)
            return referenceEntitiesByLocation[key]
        }

        func referenceEntitiesNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance) -> [ReferenceEntity] {
            let key = "\(locationKey(for: coordinate))@\(range)"
            referenceEntitiesNearCallKeys.append(key)
            return referenceEntitiesNearByLocation[key] ?? []
        }

        func referenceEntities() -> [ReferenceEntity] {
            referenceEntitiesCallCount += 1
            return referenceEntitiesToReturn
        }

        func searchByKey(_ key: String) -> POI? {
            searchByKeyCallKeys.append(key)
            return searchResultsByKey[key]
        }

        func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) throws -> String {
            addReferenceEntityCallCount += 1
            return addedReferenceEntityID
        }

        func routes() -> [Route] {
            routesCallCount += 1
            return routesToReturn
        }

        func routeByKey(_ key: String) -> Route? {
            routeByKeyCallKeys.append(key)
            return routesByKey[key]
        }

        func routesContaining(markerId: String) -> [Route] {
            routesContainingCallKeys.append(markerId)
            return routesContainingToReturn[markerId] ?? []
        }

        private func locationKey(for coordinate: CLLocationCoordinate2D) -> String {
            "\(coordinate.latitude),\(coordinate.longitude)"
        }
    }

    override func tearDownWithError() throws {
        SpatialDataStoreRegistry.resetForTesting()
        try clearAllRoutes()
    }

    func testObjectKeysDistanceUsesInjectedSpatialStoreForMarkerLookup() throws {
        let route = try createPersistedRoute(name: "DistanceTestRoute")
        let markerID = route.waypoints.ordered.first?.markerId
        XCTAssertNotNil(markerID)

        let store = MockSpatialDataStore()
        SpatialDataStoreRegistry.configure(with: store)

        let keys = Route.objectKeys(sortedBy: .distance)

        XCTAssertTrue(keys.contains(route.id))
        XCTAssertEqual(store.referenceEntityByKeyCallKeys.first, markerID)
    }

    func testRemoveWaypointFromAllRoutesUsesInjectedSpatialStoreLookup() throws {
        let store = MockSpatialDataStore()
        store.routesContainingToReturn["marker-id"] = []
        SpatialDataStoreRegistry.configure(with: store)

        try Route.removeWaypointFromAllRoutes(markerId: "marker-id")

        XCTAssertEqual(store.routesContainingCallKeys, ["marker-id"])
    }

    func testDeleteAllUsesInjectedSpatialStoreRoutesList() throws {
        let store = MockSpatialDataStore()
        store.routesToReturn = []
        SpatialDataStoreRegistry.configure(with: store)

        try Route.deleteAll()

        XCTAssertEqual(store.routesCallCount, 1)
    }

    func testEncodeFromDetailUsesInjectedSpatialStoreRouteLookup() throws {
        let route = try createPersistedRoute(name: "EncodeRoute")
        let store = MockSpatialDataStore()
        store.routesByKey[route.id] = route
        SpatialDataStoreRegistry.configure(with: store)

        let detail = RouteDetail(source: .database(id: route.id))
        let data = RouteParameters.encode(from: detail, context: .backup)

        XCTAssertNotNil(data)
        XCTAssertEqual(store.routeByKeyCallKeys, [route.id])
    }

    func testRouteInitFromParametersUsesInjectedSpatialStoreMarkerLookup() throws {
        let route = try createPersistedRoute(name: "InitFromParametersRoute")
        let firstMarkerID = route.waypoints.ordered.first?.markerId
        XCTAssertNotNil(firstMarkerID)

        guard let parameters = RouteParameters(route: route, context: .backup) else {
            XCTFail("Expected route parameters to initialize")
            return
        }

        let store = MockSpatialDataStore()
        SpatialDataStoreRegistry.configure(with: store)

        _ = Route(from: parameters)

        XCTAssertEqual(store.referenceEntityByKeyCallKeys.first, firstMarkerID)
    }

    func testMarkerParametersInitMarkerIDUsesInjectedSpatialStoreLookup() {
        let markerID = "marker-id"
        let marker = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        marker.id = markerID

        let store = MockSpatialDataStore()
        store.referenceEntitiesByKey[markerID] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let parameters = MarkerParameters(markerId: markerID)

        XCTAssertNotNil(parameters)
        XCTAssertEqual(store.referenceEntityByKeyCallKeys, [markerID])
    }

    func testMarkerParametersInitGenericLocationUsesInjectedSpatialStoreLocationLookup() {
        let genericLocation = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Generic")
        let expectedCoordinate = genericLocation.location.coordinate
        let locationLookupKey = "\(expectedCoordinate.latitude),\(expectedCoordinate.longitude)"
        let marker = ReferenceEntity(coordinate: expectedCoordinate, entityKey: nil)

        let store = MockSpatialDataStore()
        store.referenceEntitiesByLocation[locationLookupKey] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let parameters = MarkerParameters(entity: genericLocation)

        XCTAssertNotNil(parameters)
        XCTAssertEqual(store.referenceEntityByLocationCallKeys, [locationLookupKey])
    }

    func testSpatialDataStoreReferenceEntityByEntityKeyDispatchesToInjectedStore() {
        let marker = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        let entityKey = "entity-key"
        let store = MockSpatialDataStore()
        store.referenceEntitiesByEntityKey[entityKey] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let entity = SpatialDataStoreRegistry.store.referenceEntityByEntityKey(entityKey)

        XCTAssertTrue(entity === marker)
        XCTAssertEqual(store.referenceEntityByEntityKeyCallKeys, [entityKey])
    }

    func testSpatialDataStoreReferenceEntitiesNearDispatchesToInjectedStore() {
        let coordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let range = CalloutRangeContext.streetPreview.searchDistance
        let marker = ReferenceEntity(coordinate: coordinate)
        let locationLookupKey = "\(coordinate.latitude),\(coordinate.longitude)@\(range)"

        let store = MockSpatialDataStore()
        store.referenceEntitiesNearByLocation[locationLookupKey] = [marker]
        SpatialDataStoreRegistry.configure(with: store)

        let entities = SpatialDataStoreRegistry.store.referenceEntitiesNear(coordinate, range: range)

        XCTAssertEqual(entities.count, 1)
        XCTAssertTrue(entities.first === marker)
        XCTAssertEqual(store.referenceEntitiesNearCallKeys, [locationLookupKey])
    }

    func testLocationParametersFetchEntityUsesInjectedSpatialStoreSearchLookup() {
        let lookupID = "osm-lookup-id"
        let locationParameters = LocationParameters(name: "Test Entity",
                                                    address: nil,
                                                    coordinate: CoordinateParameters(latitude: 47.6205, longitude: -122.3493),
                                                    entity: EntityParameters(source: .osm, lookupInformation: lookupID))
        let cachedEntity = GDASpatialDataResultEntity(id: lookupID, parameters: locationParameters)

        let store = MockSpatialDataStore()
        store.searchResultsByKey[lookupID] = cachedEntity
        SpatialDataStoreRegistry.configure(with: store)

        let expectation = expectation(description: "fetch cached entity")
        locationParameters.fetchEntity { result in
            switch result {
            case .success(let entity):
                XCTAssertTrue((entity as AnyObject) === cachedEntity)
            case .failure(let error):
                XCTFail("Expected success but received error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(store.searchByKeyCallKeys, [lookupID])
    }

    func testRouteAddUsesInjectedSpatialStoreReferenceEntityAdd() throws {
        let expectedMarkerID = "added-from-injected-store"
        let waypointLocation = CLLocation(latitude: 47.6205, longitude: -122.3493)
        let imported = ImportedLocationDetail(nickname: "Waypoint", annotation: "Test waypoint")
        let waypointDetail = LocationDetail(location: waypointLocation, imported: imported, telemetryContext: nil)
        let waypoint = RouteWaypoint(index: 0,
                                     markerId: "initial-marker-id",
                                     importedLocationDetail: waypointDetail)
        let route = Route(name: "RouteAddInjectedStore-\(UUID().uuidString)", description: nil, waypoints: [waypoint])

        let store = MockSpatialDataStore()
        store.addedReferenceEntityID = expectedMarkerID
        SpatialDataStoreRegistry.configure(with: store)

        try Route.add(route, context: "test")

        XCTAssertEqual(store.addReferenceEntityCallCount, 1)
        XCTAssertEqual(route.waypoints.ordered.first?.markerId, expectedMarkerID)
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
