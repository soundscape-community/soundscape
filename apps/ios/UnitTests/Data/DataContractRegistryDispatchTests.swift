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
        var referenceByID: [String: RealmReferenceEntity] = [:]
        var referenceCalloutByID: [String: ReferenceCalloutReadData] = [:]
        var distanceToClosestLocationByMarkerID: [String: Double] = [:]
        var referenceMetadataByID: [String: ReferenceReadMetadata] = [:]
        var markerParametersByID: [String: MarkerParameters] = [:]
        var markerParametersByCoordinate: [String: MarkerParameters] = [:]
        var referenceMetadataByEntityKey: [String: ReferenceReadMetadata] = [:]
        var markerParametersByEntityKey: [String: MarkerParameters] = [:]
        var markerParametersToReturn: [MarkerParameters] = []
        var referenceByEntityKey: [String: RealmReferenceEntity] = [:]

        private(set) var routeByKeyCalls: [String] = []
        private(set) var routeMetadataByKeyCalls: [String] = []
        private(set) var routeParametersByKeyCalls: [String] = []
        private(set) var routeParametersForBackupCalls = 0
        private(set) var routesContainingCalls: [String] = []
        private(set) var referenceByIDCalls: [String] = []
        private(set) var referenceCalloutByIDCalls: [String] = []
        private(set) var distanceToClosestLocationCalls: [String] = []
        private(set) var referenceMetadataByIDCalls: [String] = []
        private(set) var markerParametersByIDCalls: [String] = []
        private(set) var markerParametersByCoordinateCalls: [String] = []
        private(set) var referenceMetadataByEntityKeyCalls: [String] = []
        private(set) var markerParametersByEntityKeyCalls: [String] = []
        private(set) var markerParametersForBackupCalls = 0
        private(set) var referenceByEntityKeyCalls: [String] = []
        private(set) var routeByKeySyncCalls: [String] = []
        private(set) var routeMetadataByKeySyncCalls: [String] = []
        private(set) var routeParametersByKeySyncCalls: [String] = []
        private(set) var routeParametersForBackupSyncCalls = 0
        private(set) var referenceByIDSyncCalls: [String] = []
        private(set) var referenceCalloutByIDSyncCalls: [String] = []
        private(set) var distanceToClosestLocationSyncCalls: [String] = []
        private(set) var referenceMetadataByIDSyncCalls: [String] = []
        private(set) var markerParametersByIDSyncCalls: [String] = []
        private(set) var markerParametersByCoordinateSyncCalls: [String] = []
        private(set) var referenceMetadataByEntityKeySyncCalls: [String] = []
        private(set) var markerParametersByEntityKeySyncCalls: [String] = []
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

        func referenceEntity(byID id: String) -> RealmReferenceEntity? {
            referenceByIDSyncCalls.append(id)
            return referenceByID[id]
        }

        func referenceEntity(byID id: String) async -> ReferenceEntity? {
            referenceByIDCalls.append(id)
            return referenceByID[id]?.domainEntity
        }

        func referenceCallout(byID id: String) -> ReferenceCalloutReadData? {
            referenceCalloutByIDSyncCalls.append(id)
            return referenceCalloutByID[id]
        }

        func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
            referenceCalloutByIDCalls.append(id)
            return referenceCalloutByID[id]
        }

        func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) -> Double? {
            distanceToClosestLocationSyncCalls.append(id)
            return distanceToClosestLocationByMarkerID[id]
        }

        func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
            distanceToClosestLocationCalls.append(id)
            return distanceToClosestLocationByMarkerID[id]
        }

        func referenceMetadata(byID id: String) -> ReferenceReadMetadata? {
            referenceMetadataByIDSyncCalls.append(id)
            return referenceMetadataByID[id]
        }

        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
            referenceMetadataByIDCalls.append(id)
            return referenceMetadataByID[id]
        }

        func referenceMetadata(byEntityKey key: String) -> ReferenceReadMetadata? {
            referenceMetadataByEntityKeySyncCalls.append(key)
            return referenceMetadataByEntityKey[key]
        }

        func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
            referenceMetadataByEntityKeyCalls.append(key)
            return referenceMetadataByEntityKey[key]
        }

        func markerParameters(byID id: String) -> MarkerParameters? {
            markerParametersByIDSyncCalls.append(id)
            return markerParametersByID[id]
        }

        func markerParameters(byID id: String) async -> MarkerParameters? {
            markerParametersByIDCalls.append(id)
            return markerParametersByID[id]
        }

        func markerParameters(byCoordinate coordinate: SSGeoCoordinate) -> MarkerParameters? {
            let key = coordinateKey(coordinate)
            markerParametersByCoordinateSyncCalls.append(key)
            return markerParametersByCoordinate[key]
        }

        func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? {
            let key = coordinateKey(coordinate)
            markerParametersByCoordinateCalls.append(key)
            return markerParametersByCoordinate[key]
        }

        func markerParameters(byEntityKey key: String) -> MarkerParameters? {
            markerParametersByEntityKeySyncCalls.append(key)
            return markerParametersByEntityKey[key]
        }

        func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
            markerParametersByEntityKeyCalls.append(key)
            return markerParametersByEntityKey[key]
        }

        func markerParametersForBackup() -> [MarkerParameters] {
            markerParametersForBackupSyncCalls += 1
            return markerParametersToReturn
        }

        func markerParametersForBackup() async -> [MarkerParameters] {
            markerParametersForBackupCalls += 1
            return markerParametersToReturn
        }

        func referenceEntity(byEntityKey key: String) -> RealmReferenceEntity? {
            referenceByEntityKey[key]
        }

        func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
            referenceByEntityKeyCalls.append(key)
            return referenceByEntityKey[key]?.domainEntity
        }

        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) -> RealmReferenceEntity? {
            nil
        }

        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
            nil
        }

        func referenceEntity(byGenericLocation location: GenericLocation) -> RealmReferenceEntity? {
            nil
        }

        func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
            nil
        }

        func referenceEntities() -> [RealmReferenceEntity] {
            []
        }

        func referenceEntities() async -> [ReferenceEntity] {
            []
        }

        func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) -> [RealmReferenceEntity] {
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

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: RealmReferenceEntity?) -> Set<VectorTile> {
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

        private func coordinateKey(_ coordinate: SSGeoCoordinate) -> String {
            "\(coordinate.latitude),\(coordinate.longitude)"
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

        let reference = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.62, longitude: -122.35))
        reference.id = "marker-1"
        mock.referenceByID[reference.id] = reference
        mock.referenceCalloutByID[reference.id] = ReferenceCalloutReadData(name: "Marker 1", superCategory: "undefined")
        mock.distanceToClosestLocationByMarkerID[reference.id] = 12.34
        mock.referenceMetadataByID[reference.id] = ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
        mock.markerParametersByID[reference.id] = MarkerParameters(name: "Marker 1", latitude: 47.62, longitude: -122.35)
        mock.markerParametersByCoordinate["47.62,-122.35"] = MarkerParameters(name: "Marker by Coordinate", latitude: 47.62, longitude: -122.35)
        mock.referenceMetadataByEntityKey["entity-1"] = ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
        mock.markerParametersByEntityKey["entity-1"] = MarkerParameters(name: "Marker Entity Key 1", latitude: 47.62, longitude: -122.35)
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
        let fetchedReferenceCallout = await DataContractRegistry.spatialRead.referenceCallout(byID: "marker-1")
        let markerLocation = SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 47.62, longitude: -122.35))
        let fetchedDistance = await DataContractRegistry.spatialRead.distanceToClosestLocation(forMarkerID: "marker-1",
                                                                                               from: markerLocation)
        let fetchedReferenceMetadata = await DataContractRegistry.spatialRead.referenceMetadata(byID: "marker-1")
        _ = await DataContractRegistry.spatialRead.markerParameters(byID: "marker-1")
        let fetchedMarkerParametersByCoordinate = await DataContractRegistry.spatialRead.markerParameters(byCoordinate: SSGeoCoordinate(latitude: 47.62,
                                                                                                                         longitude: -122.35))
        let fetchedReferenceMetadataByEntityKey = await DataContractRegistry.spatialRead.referenceMetadata(byEntityKey: "entity-1")
        let fetchedMarkerParametersByEntityKey = await DataContractRegistry.spatialRead.markerParameters(byEntityKey: "entity-1")
        let fetchedMarkerParameters = await DataContractRegistry.spatialRead.markerParametersForBackup()
        let fetchedReferenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: "entity-1")

        XCTAssertEqual(fetchedRoutes.count, 1)
        XCTAssertEqual(fetchedRoute?.id, route.id)
        XCTAssertEqual(fetchedRouteMetadata?.id, route.id)
        XCTAssertEqual(fetchedRouteParameter?.id, route.id)
        XCTAssertEqual(fetchedRouteParameters.count, 1)
        XCTAssertEqual(routesContainingMarker.count, 1)
        XCTAssertEqual(fetchedReferenceByID?.id, reference.id)
        XCTAssertEqual(fetchedReferenceCallout?.name, "Marker 1")
        XCTAssertEqual(fetchedDistance ?? -1, 12.34, accuracy: 0.0001)
        XCTAssertEqual(fetchedMarkerParametersByCoordinate?.location.coordinate.latitude ?? -1, 47.62, accuracy: 0.0001)
        XCTAssertEqual(fetchedMarkerParametersByCoordinate?.location.coordinate.longitude ?? -1, -122.35, accuracy: 0.0001)
        XCTAssertEqual(fetchedReferenceMetadata?.id, reference.id)
        XCTAssertEqual(fetchedReferenceMetadataByEntityKey?.id, reference.id)
        XCTAssertNotNil(fetchedMarkerParametersByEntityKey)
        XCTAssertEqual(fetchedMarkerParameters.count, 1)
        XCTAssertEqual(fetchedReferenceByEntityKey?.id, reference.id)

        XCTAssertEqual(mock.routeByKeyCalls, [route.id])
        XCTAssertEqual(mock.routeMetadataByKeyCalls, [route.id])
        XCTAssertEqual(mock.routeParametersByKeyCalls, ["\(route.id)|backup"])
        XCTAssertEqual(mock.routeParametersForBackupCalls, 1)
        XCTAssertEqual(mock.routesContainingCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceCalloutByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.distanceToClosestLocationCalls, ["marker-1"])
        XCTAssertEqual(mock.referenceMetadataByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.markerParametersByIDCalls, ["marker-1"])
        XCTAssertEqual(mock.markerParametersByCoordinateCalls, ["47.62,-122.35"])
        XCTAssertEqual(mock.referenceMetadataByEntityKeyCalls, ["entity-1"])
        XCTAssertEqual(mock.markerParametersByEntityKeyCalls, ["entity-1"])
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
        let referenceCallout = await DataContractRegistry.spatialRead.referenceCallout(byID: "missing-marker")
        let unknownMarkerLocation = SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 0, longitude: 0))
        let distance = await DataContractRegistry.spatialRead.distanceToClosestLocation(forMarkerID: "missing-marker",
                                                                                       from: unknownMarkerLocation)
        let referenceMetadata = await DataContractRegistry.spatialRead.referenceMetadata(byID: "missing-marker")
        let markerParameters = await DataContractRegistry.spatialRead.markerParameters(byID: "missing-marker")
        let markerParametersByCoordinate = await DataContractRegistry.spatialRead.markerParameters(byCoordinate: SSGeoCoordinate(latitude: 47.62,
                                                                                                                longitude: -122.35))
        let referenceMetadataByEntityKey = await DataContractRegistry.spatialRead.referenceMetadata(byEntityKey: "missing-entity-key")
        let markerParametersByEntityKey = await DataContractRegistry.spatialRead.markerParameters(byEntityKey: "missing-entity-key")

        XCTAssertNil(route)
        XCTAssertNil(routeMetadata)
        XCTAssertNil(routeParameter)
        XCTAssertNil(reference)
        XCTAssertNil(referenceCallout)
        XCTAssertNil(distance)
        XCTAssertNil(referenceMetadata)
        XCTAssertNil(markerParameters)
        XCTAssertNil(markerParametersByCoordinate)
        XCTAssertNil(referenceMetadataByEntityKey)
        XCTAssertNil(markerParametersByEntityKey)
        XCTAssertEqual(mock.routeByKeyCalls, ["missing-route"])
        XCTAssertEqual(mock.routeMetadataByKeyCalls, ["missing-route"])
        XCTAssertEqual(mock.routeParametersByKeyCalls, ["missing-route|backup"])
        XCTAssertEqual(mock.referenceByIDCalls, ["missing-marker"])
        XCTAssertEqual(mock.referenceCalloutByIDCalls, ["missing-marker"])
        XCTAssertEqual(mock.distanceToClosestLocationCalls, ["missing-marker"])
        XCTAssertEqual(mock.referenceMetadataByIDCalls, ["missing-marker"])
        XCTAssertEqual(mock.markerParametersByIDCalls, ["missing-marker"])
        XCTAssertEqual(mock.markerParametersByCoordinateCalls, ["47.62,-122.35"])
        XCTAssertEqual(mock.referenceMetadataByEntityKeyCalls, ["missing-entity-key"])
        XCTAssertEqual(mock.markerParametersByEntityKeyCalls, ["missing-entity-key"])
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
        let reference = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.62, longitude: -122.35))
        reference.id = "marker-sync"
        mock.referenceCalloutByID[reference.id] = ReferenceCalloutReadData(name: "Marker Sync", superCategory: "undefined")
        mock.distanceToClosestLocationByMarkerID[reference.id] = 5.67
        mock.referenceMetadataByID[reference.id] = ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
        mock.markerParametersByID[reference.id] = MarkerParameters(name: "Marker Sync", latitude: 47.62, longitude: -122.35)
        mock.markerParametersByCoordinate["47.62,-122.35"] = MarkerParameters(name: "Marker Coordinate Sync", latitude: 47.62, longitude: -122.35)
        mock.referenceMetadataByEntityKey["entity-sync"] = ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
        mock.markerParametersByEntityKey["entity-sync"] = MarkerParameters(name: "Marker Entity Sync", latitude: 47.62, longitude: -122.35)
        mock.markerParametersToReturn = [MarkerParameters(name: "Marker Sync", latitude: 47.62, longitude: -122.35)]

        mock.routesByKey[route.id] = route
        mock.referenceByID[reference.id] = reference
        mock.referenceByEntityKey["entity-sync"] = reference

        DataContractRegistry.configure(spatialRead: mock)

        let fetchedRoute = DataContractRegistry.spatialReadCompatibility.route(byKey: route.id)
        let fetchedRouteMetadata = DataContractRegistry.spatialReadCompatibility.routeMetadata(byKey: route.id)
        let fetchedRouteParameter = DataContractRegistry.spatialReadCompatibility.routeParameters(byKey: route.id, context: .backup)
        let fetchedRouteParameters = DataContractRegistry.spatialReadCompatibility.routeParametersForBackup()
        let fetchedReference = DataContractRegistry.spatialReadCompatibility.referenceEntity(byID: reference.id)
        let fetchedReferenceCallout = DataContractRegistry.spatialReadCompatibility.referenceCallout(byID: reference.id)
        let markerLocation = SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 47.62, longitude: -122.35))
        let fetchedDistance = DataContractRegistry.spatialReadCompatibility.distanceToClosestLocation(forMarkerID: reference.id,
                                                                                                     from: markerLocation)
        let fetchedReferenceMetadata = DataContractRegistry.spatialReadCompatibility.referenceMetadata(byID: reference.id)
        _ = DataContractRegistry.spatialReadCompatibility.markerParameters(byID: reference.id)
        let fetchedMarkerParametersByCoordinate = DataContractRegistry.spatialReadCompatibility.markerParameters(byCoordinate: SSGeoCoordinate(latitude: 47.62,
                                                                                                                             longitude: -122.35))
        let fetchedReferenceMetadataByEntityKey = DataContractRegistry.spatialReadCompatibility.referenceMetadata(byEntityKey: "entity-sync")
        let fetchedMarkerParametersByEntityKey = DataContractRegistry.spatialReadCompatibility.markerParameters(byEntityKey: "entity-sync")
        let fetchedMarkerParameters = DataContractRegistry.spatialReadCompatibility.markerParametersForBackup()

        XCTAssertEqual(fetchedRoute?.id, route.id)
        XCTAssertEqual(fetchedRouteMetadata?.id, route.id)
        XCTAssertEqual(fetchedRouteParameter?.id, route.id)
        XCTAssertEqual(fetchedRouteParameters.count, 1)
        XCTAssertEqual(fetchedReference?.id, reference.id)
        XCTAssertEqual(fetchedReferenceCallout?.name, "Marker Sync")
        XCTAssertEqual(fetchedDistance ?? -1, 5.67, accuracy: 0.0001)
        XCTAssertEqual(fetchedMarkerParametersByCoordinate?.location.coordinate.latitude ?? -1, 47.62, accuracy: 0.0001)
        XCTAssertEqual(fetchedMarkerParametersByCoordinate?.location.coordinate.longitude ?? -1, -122.35, accuracy: 0.0001)
        XCTAssertEqual(fetchedReferenceMetadata?.id, reference.id)
        XCTAssertEqual(fetchedReferenceMetadataByEntityKey?.id, reference.id)
        XCTAssertNotNil(fetchedMarkerParametersByEntityKey)
        XCTAssertEqual(fetchedMarkerParameters.count, 1)
        XCTAssertEqual(mock.routeByKeySyncCalls, [route.id])
        XCTAssertEqual(mock.routeMetadataByKeySyncCalls, [route.id])
        XCTAssertEqual(mock.routeParametersByKeySyncCalls, ["\(route.id)|backup"])
        XCTAssertEqual(mock.routeParametersForBackupSyncCalls, 1)
        XCTAssertEqual(mock.referenceByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.referenceCalloutByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.distanceToClosestLocationSyncCalls, [reference.id])
        XCTAssertEqual(mock.referenceMetadataByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.markerParametersByIDSyncCalls, [reference.id])
        XCTAssertEqual(mock.markerParametersByCoordinateSyncCalls, ["47.62,-122.35"])
        XCTAssertEqual(mock.referenceMetadataByEntityKeySyncCalls, ["entity-sync"])
        XCTAssertEqual(mock.markerParametersByEntityKeySyncCalls, ["entity-sync"])
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
