//
//  DataContractRegistryDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributers.
//

import XCTest
import CoreLocation
import SSGeo
@testable import Soundscape

@MainActor
final class DataContractRegistryDispatchTests: XCTestCase {
    private final class MockSpatialReadContract: SpatialReadContract, SpatialReadCompatibilityContract {
        var routesToReturn: [Route] = []
        var routesByKey: [String: Route] = [:]
        var routesContainingByMarkerID: [String: [Route]] = [:]
        var referenceByID: [String: ReferenceEntity] = [:]
        var referenceByEntityKey: [String: ReferenceEntity] = [:]

        private(set) var routeByKeyCalls: [String] = []
        private(set) var routesContainingCalls: [String] = []
        private(set) var referenceByIDCalls: [String] = []
        private(set) var referenceByEntityKeyCalls: [String] = []
        private(set) var routeByKeySyncCalls: [String] = []
        private(set) var referenceByIDSyncCalls: [String] = []

        func routes() -> [Route] {
            routesToReturn
        }

        func routes() async -> [Route] {
            routesToReturn
        }

        func route(byKey key: String) -> Route? {
            routeByKeySyncCalls.append(key)
            return routesByKey[key]
        }

        func route(byKey key: String) async -> Route? {
            routeByKeyCalls.append(key)
            return routesByKey[key]
        }

        func routes(containingMarkerID markerID: String) -> [Route] {
            routesContainingByMarkerID[markerID] ?? []
        }

        func routes(containingMarkerID markerID: String) async -> [Route] {
            routesContainingCalls.append(markerID)
            return routesContainingByMarkerID[markerID] ?? []
        }

        func referenceEntity(byID id: String) -> ReferenceEntity? {
            referenceByIDSyncCalls.append(id)
            return referenceByID[id]
        }

        func referenceEntity(byID id: String) async -> ReferenceEntity? {
            referenceByIDCalls.append(id)
            return referenceByID[id]
        }

        func referenceEntity(byEntityKey key: String) -> ReferenceEntity? {
            referenceByEntityKey[key]
        }

        func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
            referenceByEntityKeyCalls.append(key)
            return referenceByEntityKey[key]
        }

        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) -> ReferenceEntity? {
            nil
        }

        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
            nil
        }

        func referenceEntity(byGenericLocation location: GenericLocation) -> ReferenceEntity? {
            nil
        }

        func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
            nil
        }

        func referenceEntities() -> [ReferenceEntity] {
            []
        }

        func referenceEntities() async -> [ReferenceEntity] {
            []
        }

        func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) -> [ReferenceEntity] {
            []
        }

        func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
            []
        }

        func poi(byKey key: String) -> POI? {
            nil
        }

        func poi(byKey key: String) async -> POI? {
            nil
        }

        func road(byKey key: String) -> Road? {
            nil
        }

        func road(byKey key: String) async -> Road? {
            nil
        }

        func intersections(forRoadKey key: String) -> [Intersection] {
            []
        }

        func intersections(forRoadKey key: String) async -> [Intersection] {
            []
        }

        func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) -> Intersection? {
            nil
        }

        func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) async -> Intersection? {
            nil
        }

        func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) -> [Intersection]? {
            nil
        }

        func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) async -> [Intersection]? {
            nil
        }

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) -> Set<VectorTile> {
            []
        }

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> {
            []
        }

        func tileData(for tiles: [VectorTile]) -> [TileData] {
            []
        }

        func tileData(for tiles: [VectorTile]) async -> [TileData] {
            []
        }

        func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) -> [POI] {
            []
        }

        func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
            []
        }
    }

    override func tearDown() {
        DataContractRegistry.resetForTesting()
        super.tearDown()
    }

    func testSpatialReadDispatchesToConfiguredContract() async {
        let mock = MockSpatialReadContract()
        let route = Route()
        route.id = "route-1"
        mock.routesToReturn = [route]
        mock.routesByKey[route.id] = route
        mock.routesContainingByMarkerID["marker-1"] = [route]

        let reference = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.62, longitude: -122.35))
        reference.id = "marker-1"
        mock.referenceByID[reference.id] = reference
        mock.referenceByEntityKey["entity-1"] = reference

        DataContractRegistry.configure(spatialRead: mock)

        let fetchedRoutes = await DataContractRegistry.spatialRead.routes()
        let fetchedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)
        let routesContainingMarker = await DataContractRegistry.spatialRead.routes(containingMarkerID: "marker-1")
        let fetchedReferenceByID = await DataContractRegistry.spatialRead.referenceEntity(byID: "marker-1")
        let fetchedReferenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: "entity-1")

        XCTAssertEqual(fetchedRoutes.count, 1)
        XCTAssertEqual(fetchedRoute?.id, route.id)
        XCTAssertEqual(routesContainingMarker.count, 1)
        XCTAssertEqual(fetchedReferenceByID?.id, reference.id)
        XCTAssertEqual(fetchedReferenceByEntityKey?.id, reference.id)

        XCTAssertEqual(mock.routeByKeyCalls, [route.id])
        XCTAssertEqual(mock.routesContainingCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceByEntityKeyCalls, ["entity-1"])
    }

    func testResetForTestingRestoresDefaultRealmAdapter() {
        let mock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: mock)
        XCTAssertFalse(DataContractRegistry.spatialRead is RealmSpatialReadContract)

        DataContractRegistry.resetForTesting()

        XCTAssertTrue(DataContractRegistry.spatialRead is RealmSpatialReadContract)
    }

    func testNilPropagationForMissingEntities() async {
        let mock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: mock)

        let route = await DataContractRegistry.spatialRead.route(byKey: "missing-route")
        let reference = await DataContractRegistry.spatialRead.referenceEntity(byID: "missing-marker")

        XCTAssertNil(route)
        XCTAssertNil(reference)
        XCTAssertEqual(mock.routeByKeyCalls, ["missing-route"])
        XCTAssertEqual(mock.referenceByIDCalls, ["missing-marker"])
    }

    func testSpatialReadCompatibilityDispatchesToConfiguredContract() {
        let mock = MockSpatialReadContract()
        let route = Route()
        route.id = "route-sync"
        let reference = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.62, longitude: -122.35))
        reference.id = "marker-sync"

        mock.routesByKey[route.id] = route
        mock.referenceByID[reference.id] = reference

        DataContractRegistry.configure(spatialRead: mock)

        let fetchedRoute = DataContractRegistry.spatialReadCompatibility.route(byKey: route.id)
        let fetchedReference = DataContractRegistry.spatialReadCompatibility.referenceEntity(byID: reference.id)

        XCTAssertEqual(fetchedRoute?.id, route.id)
        XCTAssertEqual(fetchedReference?.id, reference.id)
        XCTAssertEqual(mock.routeByKeySyncCalls, [route.id])
        XCTAssertEqual(mock.referenceByIDSyncCalls, [reference.id])
    }
}
