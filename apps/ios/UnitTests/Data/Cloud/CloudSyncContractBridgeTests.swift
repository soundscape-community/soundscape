//
//  CloudSyncContractBridgeTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributers.
//

import XCTest
import SSGeo
@testable import Soundscape

@MainActor
final class CloudSyncContractBridgeTests: XCTestCase {
    private final class MockSpatialReadContract: SpatialReadContract {
        var routesByKey: [String: Route] = [:]
        var routeMetadataByKey: [String: RouteReadMetadata] = [:]
        var routeParametersForBackupResults: [RouteParameters] = []
        var markerParametersForBackupResults: [MarkerParameters] = []
        private(set) var routeByKeyCalls: [String] = []
        private(set) var routeMetadataByKeyCalls: [String] = []
        private(set) var routeParametersForBackupCalls = 0
        private(set) var markerParametersForBackupCalls = 0

        var onRouteByKey: ((String) -> Void)?
        var onRouteMetadataByKey: ((String) -> Void)?

        func routes() async -> [Route] {
            []
        }

        func route(byKey key: String) async -> Route? {
            routeByKeyCalls.append(key)
            onRouteByKey?(key)
            return routesByKey[key]
        }

        func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
            routeMetadataByKeyCalls.append(key)
            onRouteMetadataByKey?(key)
            return routeMetadataByKey[key]
        }

        func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
            nil
        }

        func routeParametersForBackup() async -> [RouteParameters] {
            routeParametersForBackupCalls += 1
            return routeParametersForBackupResults
        }

        func routes(containingMarkerID markerID: String) async -> [Route] {
            []
        }

        func referenceEntity(byID id: String) async -> ReferenceEntity? {
            nil
        }

        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
            nil
        }

        func markerParameters(byID id: String) async -> MarkerParameters? {
            nil
        }

        func markerParametersForBackup() async -> [MarkerParameters] {
            markerParametersForBackupCalls += 1
            return markerParametersForBackupResults
        }

        func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
            nil
        }

        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
            nil
        }

        func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
            nil
        }

        func referenceEntities() async -> [ReferenceEntity] {
            []
        }

        func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
            []
        }

        func poi(byKey key: String) async -> POI? {
            nil
        }

        func road(byKey key: String) async -> Road? {
            nil
        }

        func intersections(forRoadKey key: String) async -> [Intersection] {
            []
        }

        func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) async -> Intersection? {
            nil
        }

        func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) async -> [Intersection]? {
            nil
        }

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> {
            []
        }

        func tileData(for tiles: [VectorTile]) async -> [TileData] {
            []
        }

        func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
            []
        }
    }

    private final class TestCloudKeyValueStore: CloudKeyValueStore {
        var storage: [String: Any] = [:]

        override var allKeys: Set<String> {
            Set(storage.keys)
        }

        override func object(forKey key: String) -> Any? {
            storage[key]
        }

        override func set(object: Any?, forKey key: String) {
            storage[key] = object
        }

        override func removeObject(forKey key: String) {
            storage.removeValue(forKey: key)
        }

        override func synchronize() {
            // no-op for deterministic tests
        }
    }

    override func tearDown() {
        DataContractRegistry.resetForTesting()
        super.tearDown()
    }

    func testSyncReferenceEntitiesCompletionFiresExactlyOnce() {
        let store = TestCloudKeyValueStore()

        let completionExpectation = expectation(description: "completion")
        var completionCount = 0

        store.syncReferenceEntities(reason: .serverChanged) {
            completionCount += 1
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)
        XCTAssertEqual(completionCount, 1)
    }

    func testSyncRoutesChangedKeyFilteringUsesContractRouteLookup() {
        let id = "route-1"
        let routeKey = "routes.\(id)"

        let localRoute = Route()
        localRoute.id = id
        localRoute.lastUpdatedDate = Date(timeIntervalSince1970: 1_000)

        let mock = MockSpatialReadContract()
        mock.routesByKey[id] = localRoute
        mock.routeMetadataByKey[id] = RouteReadMetadata(id: id, lastUpdatedDate: localRoute.lastUpdatedDate)
        DataContractRegistry.configure(spatialRead: mock)

        let store = TestCloudKeyValueStore()
        store.storage[routeKey] = makeRouteData(id: id, lastUpdatedDate: Date(timeIntervalSince1970: 1_000))

        let lookupExpectation = expectation(description: "route metadata lookup")
        mock.onRouteMetadataByKey = { lookedUpID in
            if lookedUpID == id {
                lookupExpectation.fulfill()
            }
        }

        store.syncRoutes(reason: .serverChanged, changedKeys: [routeKey])

        wait(for: [lookupExpectation], timeout: 2.0)
        XCTAssertEqual(mock.routeMetadataByKeyCalls, [id])
        XCTAssertTrue(mock.routeByKeyCalls.isEmpty)
    }

    func testSyncRoutesFallbackWhenCloudDataIsInvalid() async {
        let mock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: mock)

        let store = TestCloudKeyValueStore()
        store.storage["routes.invalid"] = Data("invalid-json".utf8)

        await store.syncRoutesAsync(reason: .serverChanged, changedKeys: ["routes.invalid"])

        XCTAssertTrue(mock.routeMetadataByKeyCalls.isEmpty)
    }

    func testSyncRoutesInitialSyncUsesContractBackupParameters() async {
        let id = "route-export-1"
        let routeParameters = RouteParameters(id: id,
                                              name: "Export Route",
                                              routeDescription: nil,
                                              waypoints: [],
                                              createdDate: nil,
                                              lastUpdatedDate: Date(timeIntervalSince1970: 1_000),
                                              lastSelectedDate: nil)

        let mock = MockSpatialReadContract()
        mock.routeParametersForBackupResults = [routeParameters]
        DataContractRegistry.configure(spatialRead: mock)

        let store = TestCloudKeyValueStore()
        await store.syncRoutesAsync(reason: .initialSync, changedKeys: nil)

        XCTAssertEqual(mock.routeParametersForBackupCalls, 1)
        XCTAssertNotNil(store.storage["routes.\(id)"] as? Data)
    }

    func testSyncReferenceEntitiesInitialSyncUsesContractBackupParameters() async {
        let mock = MockSpatialReadContract()
        mock.markerParametersForBackupResults = []
        DataContractRegistry.configure(spatialRead: mock)

        let store = TestCloudKeyValueStore()
        await store.syncReferenceEntitiesAsync(reason: .initialSync, changedKeys: nil)

        XCTAssertEqual(mock.markerParametersForBackupCalls, 1)
    }

    private func makeRouteData(id: String, lastUpdatedDate: Date?) -> Data {
        let routeParameters = RouteParameters(id: id,
                                              name: "Route \(id)",
                                              routeDescription: nil,
                                              waypoints: [],
                                              createdDate: nil,
                                              lastUpdatedDate: lastUpdatedDate,
                                              lastSelectedDate: nil)

        do {
            return try JSONEncoder().encode(routeParameters)
        } catch {
            XCTFail("Failed to encode route parameters: \(error)")
            return Data()
        }
    }
}
