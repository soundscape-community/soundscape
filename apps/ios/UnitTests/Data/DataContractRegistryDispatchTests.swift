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
        var routeMetadataByKey: [String: RouteReadMetadata] = [:]
        var routeParametersByLookupKey: [String: RouteParameters] = [:]
        var routeParametersToReturn: [RouteParameters] = []
        var routesContainingByMarkerID: [String: [Route]] = [:]
        var referenceByID: [String: ReferenceEntity] = [:]
        var referenceMetadataByID: [String: ReferenceReadMetadata] = [:]
        var markerParametersByID: [String: MarkerParameters] = [:]
        var markerParametersToReturn: [MarkerParameters] = []
        var referenceByEntityKey: [String: ReferenceEntity] = [:]

        private(set) var routeByKeyCalls: [String] = []
        private(set) var routeMetadataByKeyCalls: [String] = []
        private(set) var routeParametersByKeyCalls: [String] = []
        private(set) var routeParametersForBackupCalls = 0
        private(set) var routesContainingCalls: [String] = []
        private(set) var referenceByIDCalls: [String] = []
        private(set) var referenceMetadataByIDCalls: [String] = []
        private(set) var markerParametersByIDCalls: [String] = []
        private(set) var markerParametersForBackupCalls = 0
        private(set) var referenceByEntityKeyCalls: [String] = []
        private(set) var routeByKeySyncCalls: [String] = []
        private(set) var routeMetadataByKeySyncCalls: [String] = []
        private(set) var routeParametersByKeySyncCalls: [String] = []
        private(set) var routeParametersForBackupSyncCalls = 0
        private(set) var referenceByIDSyncCalls: [String] = []
        private(set) var referenceMetadataByIDSyncCalls: [String] = []
        private(set) var markerParametersByIDSyncCalls: [String] = []
        private(set) var markerParametersForBackupSyncCalls = 0

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

        func routeMetadata(byKey key: String) -> RouteReadMetadata? {
            routeMetadataByKeySyncCalls.append(key)
            return routeMetadataByKey[key]
        }

        func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
            routeMetadataByKeyCalls.append(key)
            return routeMetadataByKey[key]
        }

        func routeParameters(byKey key: String, context: RouteParameters.Context) -> RouteParameters? {
            let lookupKey = "\(key)|\(contextKey(context))"
            routeParametersByKeySyncCalls.append(lookupKey)
            return routeParametersByLookupKey[lookupKey]
        }

        func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
            let lookupKey = "\(key)|\(contextKey(context))"
            routeParametersByKeyCalls.append(lookupKey)
            return routeParametersByLookupKey[lookupKey]
        }

        func routeParametersForBackup() -> [RouteParameters] {
            routeParametersForBackupSyncCalls += 1
            return routeParametersToReturn
        }

        func routeParametersForBackup() async -> [RouteParameters] {
            routeParametersForBackupCalls += 1
            return routeParametersToReturn
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

        func referenceMetadata(byID id: String) -> ReferenceReadMetadata? {
            referenceMetadataByIDSyncCalls.append(id)
            return referenceMetadataByID[id]
        }

        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
            referenceMetadataByIDCalls.append(id)
            return referenceMetadataByID[id]
        }

        func markerParameters(byID id: String) -> MarkerParameters? {
            markerParametersByIDSyncCalls.append(id)
            return markerParametersByID[id]
        }

        func markerParameters(byID id: String) async -> MarkerParameters? {
            markerParametersByIDCalls.append(id)
            return markerParametersByID[id]
        }

        func markerParametersForBackup() -> [MarkerParameters] {
            markerParametersForBackupSyncCalls += 1
            return markerParametersToReturn
        }

        func markerParametersForBackup() async -> [MarkerParameters] {
            markerParametersForBackupCalls += 1
            return markerParametersToReturn
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

        private func contextKey(_ context: RouteParameters.Context) -> String {
            switch context {
            case .backup:
                return "backup"
            case .share:
                return "share"
            }
        }
    }

    private final class MockSpatialWriteContract: SpatialWriteContract, SpatialWriteCompatibilityContract {
        var markerIDsByEntityKey: [String: String] = [:]
        var nextTemporaryID = "temp-marker-id"
        private(set) var addReferenceEntityCalls: [String?] = []
        private(set) var addTemporaryEntityKeyCalls: [String] = []
        private(set) var removeAllTemporaryCalls = 0

        func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) throws -> String {
            addReferenceEntityCalls.append(telemetryContext)
            return detail.markerId ?? "generated-marker-id"
        }

        func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) async throws -> String {
            try (self as SpatialWriteCompatibilityContract).addReferenceEntity(detail: detail,
                                                                               telemetryContext: telemetryContext,
                                                                               notify: notify)
        }

        func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String {
            nextTemporaryID
        }

        func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String {
            try (self as SpatialWriteCompatibilityContract).addTemporaryReferenceEntity(location: location,
                                                                                        estimatedAddress: estimatedAddress)
        }

        func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String {
            nextTemporaryID
        }

        func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String {
            try (self as SpatialWriteCompatibilityContract).addTemporaryReferenceEntity(location: location,
                                                                                        nickname: nickname,
                                                                                        estimatedAddress: estimatedAddress)
        }

        func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String {
            addTemporaryEntityKeyCalls.append(entityKey)
            return markerIDsByEntityKey[entityKey] ?? nextTemporaryID
        }

        func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String {
            try (self as SpatialWriteCompatibilityContract).addTemporaryReferenceEntity(entityKey: entityKey,
                                                                                        estimatedAddress: estimatedAddress)
        }

        func removeAllTemporaryReferenceEntities() throws {
            removeAllTemporaryCalls += 1
        }

        func removeAllTemporaryReferenceEntities() async throws {
            try (self as SpatialWriteCompatibilityContract).removeAllTemporaryReferenceEntities()
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
        mock.routeMetadataByKey[route.id] = RouteReadMetadata(id: route.id, lastUpdatedDate: route.lastUpdatedDate)
        mock.routeParametersByLookupKey["\(route.id)|backup"] = RouteParameters(id: route.id,
                                                                                name: "Route 1",
                                                                                routeDescription: nil,
                                                                                waypoints: [],
                                                                                createdDate: nil,
                                                                                lastUpdatedDate: route.lastUpdatedDate,
                                                                                lastSelectedDate: nil)
        mock.routeParametersToReturn = [RouteParameters(id: route.id,
                                                       name: "Route 1",
                                                       routeDescription: nil,
                                                       waypoints: [],
                                                       createdDate: nil,
                                                       lastUpdatedDate: route.lastUpdatedDate,
                                                       lastSelectedDate: nil)]
        mock.routesContainingByMarkerID["marker-1"] = [route]

        let reference = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.62, longitude: -122.35))
        reference.id = "marker-1"
        mock.referenceByID[reference.id] = reference
        mock.referenceMetadataByID[reference.id] = ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
        mock.markerParametersByID[reference.id] = MarkerParameters(name: "Marker 1", latitude: 47.62, longitude: -122.35)
        mock.markerParametersToReturn = [MarkerParameters(name: "Marker 1", latitude: 47.62, longitude: -122.35)]
        mock.referenceByEntityKey["entity-1"] = reference

        DataContractRegistry.configure(spatialRead: mock)

        let fetchedRoutes = await DataContractRegistry.spatialRead.routes()
        let fetchedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)
        let fetchedRouteMetadata = await DataContractRegistry.spatialRead.routeMetadata(byKey: route.id)
        let fetchedRouteParameter = await DataContractRegistry.spatialRead.routeParameters(byKey: route.id, context: .backup)
        let fetchedRouteParameters = await DataContractRegistry.spatialRead.routeParametersForBackup()
        let routesContainingMarker = await DataContractRegistry.spatialRead.routes(containingMarkerID: "marker-1")
        let fetchedReferenceByID = await DataContractRegistry.spatialRead.referenceEntity(byID: "marker-1")
        let fetchedReferenceMetadata = await DataContractRegistry.spatialRead.referenceMetadata(byID: "marker-1")
        _ = await DataContractRegistry.spatialRead.markerParameters(byID: "marker-1")
        let fetchedMarkerParameters = await DataContractRegistry.spatialRead.markerParametersForBackup()
        let fetchedReferenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: "entity-1")

        XCTAssertEqual(fetchedRoutes.count, 1)
        XCTAssertEqual(fetchedRoute?.id, route.id)
        XCTAssertEqual(fetchedRouteMetadata?.id, route.id)
        XCTAssertEqual(fetchedRouteParameter?.id, route.id)
        XCTAssertEqual(fetchedRouteParameters.count, 1)
        XCTAssertEqual(routesContainingMarker.count, 1)
        XCTAssertEqual(fetchedReferenceByID?.id, reference.id)
        XCTAssertEqual(fetchedReferenceMetadata?.id, reference.id)
        XCTAssertEqual(fetchedMarkerParameters.count, 1)
        XCTAssertEqual(fetchedReferenceByEntityKey?.id, reference.id)

        XCTAssertEqual(mock.routeByKeyCalls, [route.id])
        XCTAssertEqual(mock.routeMetadataByKeyCalls, [route.id])
        XCTAssertEqual(mock.routeParametersByKeyCalls, ["\(route.id)|backup"])
        XCTAssertEqual(mock.routeParametersForBackupCalls, 1)
        XCTAssertEqual(mock.routesContainingCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceMetadataByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.markerParametersByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.markerParametersForBackupCalls, 1)
        XCTAssertEqual(mock.referenceByEntityKeyCalls, ["entity-1"])
    }

    func testResetForTestingRestoresDefaultRealmAdapter() {
        let mock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: mock)
        XCTAssertFalse(DataContractRegistry.spatialRead is RealmSpatialReadContract)
        XCTAssertTrue(DataContractRegistry.spatialWrite is RealmSpatialWriteContract)

        DataContractRegistry.resetForTesting()

        XCTAssertTrue(DataContractRegistry.spatialRead is RealmSpatialReadContract)
        XCTAssertTrue(DataContractRegistry.spatialWrite is RealmSpatialWriteContract)
    }

    func testNilPropagationForMissingEntities() async {
        let mock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: mock)

        let route = await DataContractRegistry.spatialRead.route(byKey: "missing-route")
        let routeMetadata = await DataContractRegistry.spatialRead.routeMetadata(byKey: "missing-route")
        let routeParameter = await DataContractRegistry.spatialRead.routeParameters(byKey: "missing-route", context: .backup)
        let reference = await DataContractRegistry.spatialRead.referenceEntity(byID: "missing-marker")
        let referenceMetadata = await DataContractRegistry.spatialRead.referenceMetadata(byID: "missing-marker")
        let markerParameters = await DataContractRegistry.spatialRead.markerParameters(byID: "missing-marker")

        XCTAssertNil(route)
        XCTAssertNil(routeMetadata)
        XCTAssertNil(routeParameter)
        XCTAssertNil(reference)
        XCTAssertNil(referenceMetadata)
        XCTAssertNil(markerParameters)
        XCTAssertEqual(mock.routeByKeyCalls, ["missing-route"])
        XCTAssertEqual(mock.routeMetadataByKeyCalls, ["missing-route"])
        XCTAssertEqual(mock.routeParametersByKeyCalls, ["missing-route|backup"])
        XCTAssertEqual(mock.referenceByIDCalls, ["missing-marker"])
        XCTAssertEqual(mock.referenceMetadataByIDCalls, ["missing-marker"])
        XCTAssertEqual(mock.markerParametersByIDCalls, ["missing-marker"])
    }

    func testSpatialReadCompatibilityDispatchesToConfiguredContract() {
        let mock = MockSpatialReadContract()
        let route = Route()
        route.id = "route-sync"
        mock.routeMetadataByKey[route.id] = RouteReadMetadata(id: route.id, lastUpdatedDate: route.lastUpdatedDate)
        mock.routeParametersByLookupKey["\(route.id)|backup"] = RouteParameters(id: route.id,
                                                                                name: "Route Sync",
                                                                                routeDescription: nil,
                                                                                waypoints: [],
                                                                                createdDate: nil,
                                                                                lastUpdatedDate: route.lastUpdatedDate,
                                                                                lastSelectedDate: nil)
        mock.routeParametersToReturn = [RouteParameters(id: route.id,
                                                       name: "Route Sync",
                                                       routeDescription: nil,
                                                       waypoints: [],
                                                       createdDate: nil,
                                                       lastUpdatedDate: route.lastUpdatedDate,
                                                       lastSelectedDate: nil)]
        let reference = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.62, longitude: -122.35))
        reference.id = "marker-sync"
        mock.referenceMetadataByID[reference.id] = ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
        mock.markerParametersByID[reference.id] = MarkerParameters(name: "Marker Sync", latitude: 47.62, longitude: -122.35)
        mock.markerParametersToReturn = [MarkerParameters(name: "Marker Sync", latitude: 47.62, longitude: -122.35)]

        mock.routesByKey[route.id] = route
        mock.referenceByID[reference.id] = reference

        DataContractRegistry.configure(spatialRead: mock)

        let fetchedRoute = DataContractRegistry.spatialReadCompatibility.route(byKey: route.id)
        let fetchedRouteMetadata = DataContractRegistry.spatialReadCompatibility.routeMetadata(byKey: route.id)
        let fetchedRouteParameter = DataContractRegistry.spatialReadCompatibility.routeParameters(byKey: route.id, context: .backup)
        let fetchedRouteParameters = DataContractRegistry.spatialReadCompatibility.routeParametersForBackup()
        let fetchedReference = DataContractRegistry.spatialReadCompatibility.referenceEntity(byID: reference.id)
        let fetchedReferenceMetadata = DataContractRegistry.spatialReadCompatibility.referenceMetadata(byID: reference.id)
        _ = DataContractRegistry.spatialReadCompatibility.markerParameters(byID: reference.id)
        let fetchedMarkerParameters = DataContractRegistry.spatialReadCompatibility.markerParametersForBackup()

        XCTAssertEqual(fetchedRoute?.id, route.id)
        XCTAssertEqual(fetchedRouteMetadata?.id, route.id)
        XCTAssertEqual(fetchedRouteParameter?.id, route.id)
        XCTAssertEqual(fetchedRouteParameters.count, 1)
        XCTAssertEqual(fetchedReference?.id, reference.id)
        XCTAssertEqual(fetchedReferenceMetadata?.id, reference.id)
        XCTAssertEqual(fetchedMarkerParameters.count, 1)
        XCTAssertEqual(mock.routeByKeySyncCalls, [route.id])
        XCTAssertEqual(mock.routeMetadataByKeySyncCalls, [route.id])
        XCTAssertEqual(mock.routeParametersByKeySyncCalls, ["\(route.id)|backup"])
        XCTAssertEqual(mock.routeParametersForBackupSyncCalls, 1)
        XCTAssertEqual(mock.referenceByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.referenceMetadataByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.markerParametersByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.markerParametersForBackupSyncCalls, 1)
    }

    func testSpatialWriteCompatibilityDispatchesToConfiguredContract() throws {
        let readMock = MockSpatialReadContract()
        let writeMock = MockSpatialWriteContract()
        writeMock.markerIDsByEntityKey["entity-1"] = "marker-1"

        DataContractRegistry.configure(spatialRead: readMock, spatialWrite: writeMock)

        let markerID = try DataContractRegistry.spatialWriteCompatibility.addTemporaryReferenceEntity(entityKey: "entity-1",
                                                                                                      estimatedAddress: "123 Main")
        try DataContractRegistry.spatialWriteCompatibility.removeAllTemporaryReferenceEntities()

        XCTAssertEqual(markerID, "marker-1")
        XCTAssertEqual(writeMock.addTemporaryEntityKeyCalls, ["entity-1"])
        XCTAssertEqual(writeMock.removeAllTemporaryCalls, 1)
    }
}
