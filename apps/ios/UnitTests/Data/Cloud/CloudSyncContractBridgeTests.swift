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
        var referenceByID: [String: ReferenceEntity] = [:]
        private(set) var routeByKeyCalls: [String] = []
        private(set) var routeMetadataByKeyCalls: [String] = []
        private(set) var routeParametersForBackupCalls = 0
        private(set) var markerParametersForBackupCalls = 0
        private(set) var referenceByIDCalls: [String] = []

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
            referenceByIDCalls.append(id)
            return referenceByID[id]
        }

        func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
            nil
        }

        func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
            nil
        }

        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
            nil
        }

        func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
            nil
        }

        func markerParameters(byID id: String) async -> MarkerParameters? {
            nil
        }

        func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? {
            nil
        }

        func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
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

        func recentlySelectedPOIs() async -> [POI] {
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

    private final class MockSpatialWriteContract: SpatialWriteContract {
        func addRoute(_ route: Route) async throws {}

        func deleteRoute(id: String) async throws {}

        func updateRoute(_ route: Route) async throws {}

        func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
            "generated-marker-id"
        }

        func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
            "generated-marker-id"
        }

        func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws {}

        func removeReferenceEntity(id: String) async throws {}
    }

    private final class MockSpatialMaintenanceWriteContract: SpatialMaintenanceWriteContract {
        private(set) var importedRouteIDs: [String] = []
        private(set) var importedMarkerIDs: [String] = []
        private(set) var importedRoutes: [Route] = []

        func importRouteFromCloud(_ route: Route) async throws {
            importedRouteIDs.append(route.id)
            importedRoutes.append(route)
        }

        func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws {
            if let markerID = markerParameters.id {
                importedMarkerIDs.append(markerID)
            }
        }

        func removeAllReferenceEntities() async throws {}

        func removeAllRoutes() async throws {}

        func clearNewReferenceEntitiesAndRoutes() async throws {}

        func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws {}

        func cleanCorruptReferenceEntities() async throws {}
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

        var localRoute = Route()
        localRoute.id = id
        localRoute.lastUpdatedDate = Date(timeIntervalSince1970: 1_000)

        let mock = MockSpatialReadContract()
        mock.routesByKey[id] = localRoute
        mock.routeMetadataByKey[id] = RouteReadMetadata(id: id, lastUpdatedDate: localRoute.lastUpdatedDate)
        let writeMock = MockSpatialWriteContract()
        DataContractRegistry.configure(spatialRead: mock, spatialWrite: writeMock)

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
        let writeMock = MockSpatialWriteContract()
        DataContractRegistry.configure(spatialRead: mock, spatialWrite: writeMock)

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
        let writeMock = MockSpatialWriteContract()
        DataContractRegistry.configure(spatialRead: mock, spatialWrite: writeMock)

        let store = TestCloudKeyValueStore()
        await store.syncRoutesAsync(reason: .initialSync, changedKeys: nil)

        XCTAssertEqual(mock.routeParametersForBackupCalls, 1)
        XCTAssertNotNil(store.storage["routes.\(id)"] as? Data)
    }

    func testSyncReferenceEntitiesInitialSyncUsesContractBackupParameters() async {
        let mock = MockSpatialReadContract()
        mock.markerParametersForBackupResults = []
        let writeMock = MockSpatialWriteContract()
        DataContractRegistry.configure(spatialRead: mock, spatialWrite: writeMock)

        let store = TestCloudKeyValueStore()
        await store.syncReferenceEntitiesAsync(reason: .initialSync, changedKeys: nil)

        XCTAssertEqual(mock.markerParametersForBackupCalls, 1)
    }

    func testSyncRoutesChangedKeyImportUsesMaintenanceContractRouteImport() async {
        let id = "route-import-1"
        let routeKey = "routes.\(id)"

        let readMock = MockSpatialReadContract()
        let writeMock = MockSpatialWriteContract()
        let maintenanceMock = MockSpatialMaintenanceWriteContract()
        DataContractRegistry.configure(spatialRead: readMock,
                                       spatialWrite: writeMock,
                                       spatialMaintenanceWrite: maintenanceMock)

        let store = TestCloudKeyValueStore()
        store.storage[routeKey] = makeRouteData(id: id, lastUpdatedDate: Date(timeIntervalSince1970: 2_000))

        await store.syncRoutesAsync(reason: .serverChanged, changedKeys: [routeKey])

        XCTAssertEqual(maintenanceMock.importedRouteIDs, [id])
    }

    func testSyncReferenceEntitiesChangedKeyImportUsesMaintenanceContractMarkerImport() async {
        let id = "marker-import-1"
        let markerKey = "marker.\(id)"

        let readMock = MockSpatialReadContract()
        let writeMock = MockSpatialWriteContract()
        let maintenanceMock = MockSpatialMaintenanceWriteContract()
        DataContractRegistry.configure(spatialRead: readMock,
                                       spatialWrite: writeMock,
                                       spatialMaintenanceWrite: maintenanceMock)

        let store = TestCloudKeyValueStore()
        store.storage[markerKey] = makeMarkerData(id: id,
                                                  name: "Marker \(id)",
                                                  latitude: 47.62,
                                                  longitude: -122.35,
                                                  lastUpdatedDate: Date(timeIntervalSince1970: 2_000))

        await store.syncReferenceEntitiesAsync(reason: .serverChanged, changedKeys: [markerKey])

        XCTAssertEqual(maintenanceMock.importedMarkerIDs, [id])
    }

    func testSyncRoutesChangedKeyImportHydratesFirstWaypointFromAsyncReadContract() async {
        let id = "route-import-hydrate-1"
        let markerID = "route-import-marker-1"
        let routeKey = "routes.\(id)"
        let expectedCoordinate = SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493)

        let readMock = MockSpatialReadContract()
        readMock.referenceByID[markerID] = ReferenceEntity(id: markerID,
                                                           entityKey: nil,
                                                           lastUpdatedDate: nil,
                                                           lastSelectedDate: nil,
                                                           isNew: false,
                                                           isTemp: false,
                                                           coordinate: expectedCoordinate,
                                                           nickname: nil,
                                                           estimatedAddress: nil,
                                                           annotation: nil)
        let writeMock = MockSpatialWriteContract()
        let maintenanceMock = MockSpatialMaintenanceWriteContract()
        DataContractRegistry.configure(spatialRead: readMock,
                                       spatialWrite: writeMock,
                                       spatialMaintenanceWrite: maintenanceMock)

        let store = TestCloudKeyValueStore()
        store.storage[routeKey] = makeRouteData(id: id,
                                                lastUpdatedDate: Date(timeIntervalSince1970: 2_000),
                                                waypoints: [RouteWaypointParameters(index: 0, markerId: markerID, marker: nil)])

        await store.syncRoutesAsync(reason: .serverChanged, changedKeys: [routeKey])

        XCTAssertEqual(maintenanceMock.importedRouteIDs, [id])
        XCTAssertEqual(readMock.referenceByIDCalls, [markerID])
        XCTAssertEqual(maintenanceMock.importedRoutes.first?.firstWaypointLatitude ?? 0,
                       expectedCoordinate.latitude,
                       accuracy: 0.000_001)
        XCTAssertEqual(maintenanceMock.importedRoutes.first?.firstWaypointLongitude ?? 0,
                       expectedCoordinate.longitude,
                       accuracy: 0.000_001)
    }

    func testSyncRoutesChangedKeyImportPrefersWaypointPayloadCoordinateOverAsyncReadContract() async {
        let id = "route-import-payload-first-1"
        let markerID = "route-import-payload-marker-1"
        let routeKey = "routes.\(id)"
        let payloadCoordinate = MarkerParameters(name: "Payload Marker",
                                                 latitude: 47.6205,
                                                 longitude: -122.3493)
        let readCoordinate = SSGeoCoordinate(latitude: 48.1122, longitude: -122.7711)

        let readMock = MockSpatialReadContract()
        readMock.referenceByID[markerID] = ReferenceEntity(id: markerID,
                                                           entityKey: nil,
                                                           lastUpdatedDate: nil,
                                                           lastSelectedDate: nil,
                                                           isNew: false,
                                                           isTemp: false,
                                                           coordinate: readCoordinate,
                                                           nickname: nil,
                                                           estimatedAddress: nil,
                                                           annotation: nil)
        let writeMock = MockSpatialWriteContract()
        let maintenanceMock = MockSpatialMaintenanceWriteContract()
        DataContractRegistry.configure(spatialRead: readMock,
                                       spatialWrite: writeMock,
                                       spatialMaintenanceWrite: maintenanceMock)

        let store = TestCloudKeyValueStore()
        store.storage[routeKey] = makeRouteData(id: id,
                                                lastUpdatedDate: Date(timeIntervalSince1970: 2_000),
                                                waypoints: [RouteWaypointParameters(index: 0,
                                                                                    markerId: markerID,
                                                                                    marker: payloadCoordinate)])

        await store.syncRoutesAsync(reason: .serverChanged, changedKeys: [routeKey])

        XCTAssertEqual(maintenanceMock.importedRouteIDs, [id])
        XCTAssertTrue(readMock.referenceByIDCalls.isEmpty)
        XCTAssertEqual(maintenanceMock.importedRoutes.first?.firstWaypointLatitude ?? 0,
                       payloadCoordinate.location.coordinate.latitude,
                       accuracy: 0.000_001)
        XCTAssertEqual(maintenanceMock.importedRoutes.first?.firstWaypointLongitude ?? 0,
                       payloadCoordinate.location.coordinate.longitude,
                       accuracy: 0.000_001)
    }

    private func makeRouteData(id: String, lastUpdatedDate: Date?, waypoints: [RouteWaypointParameters] = []) -> Data {
        let routeParameters = RouteParameters(id: id,
                                              name: "Route \(id)",
                                              routeDescription: nil,
                                              waypoints: waypoints,
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

    private func makeMarkerData(id: String, name: String, latitude: Double, longitude: Double, lastUpdatedDate: Date?) -> Data {
        struct MarkerPayload: Encodable {
            struct LocationPayload: Encodable {
                struct CoordinatePayload: Encodable {
                    let latitude: Double
                    let longitude: Double
                }

                let name: String
                let address: String?
                let coordinate: CoordinatePayload
                let entity: EntityParameters?
            }

            let id: String
            let nickname: String?
            let annotation: String?
            let estimatedAddress: String?
            let lastUpdatedDate: Date?
            let location: LocationPayload
        }

        let payload = MarkerPayload(id: id,
                                    nickname: name,
                                    annotation: nil,
                                    estimatedAddress: nil,
                                    lastUpdatedDate: lastUpdatedDate,
                                    location: MarkerPayload.LocationPayload(name: name,
                                                                           address: nil,
                                                                           coordinate: MarkerPayload.LocationPayload.CoordinatePayload(latitude: latitude,
                                                                                                                                      longitude: longitude),
                                                                           entity: nil))

        do {
            return try JSONEncoder().encode(payload)
        } catch {
            XCTFail("Failed to encode marker parameters: \(error)")
            return Data()
        }
    }
}
