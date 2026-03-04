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
    private final class MockSpatialReadContract: SpatialReadContract {
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

        func routes() async -> [Route] {
            routesToReturn
        }

        func route(byKey key: String) async -> Route? {
            routeByKeyCalls.append(key)
            return routesByKey[key]
        }

        func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
            routeMetadataByKeyCalls.append(key)
            return routeMetadataByKey[key]
        }

        func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
            let lookupKey = "\(key)|\(contextKey(context))"
            routeParametersByKeyCalls.append(lookupKey)
            return routeParametersByLookupKey[lookupKey]
        }

        func routeParametersForBackup() async -> [RouteParameters] {
            routeParametersForBackupCalls += 1
            return routeParametersToReturn
        }

        func routes(containingMarkerID markerID: String) async -> [Route] {
            routesContainingCalls.append(markerID)
            return routesContainingByMarkerID[markerID] ?? []
        }

        func referenceEntity(byID id: String) async -> ReferenceEntity? {
            referenceByIDCalls.append(id)
            return referenceByID[id]?.domainEntity
        }

        func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
            referenceCalloutByIDCalls.append(id)
            return referenceCalloutByID[id]
        }

        func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
            distanceToClosestLocationCalls.append(id)
            return distanceToClosestLocationByMarkerID[id]
        }

        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
            referenceMetadataByIDCalls.append(id)
            return referenceMetadataByID[id]
        }

        func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
            referenceMetadataByEntityKeyCalls.append(key)
            return referenceMetadataByEntityKey[key]
        }

        func markerParameters(byID id: String) async -> MarkerParameters? {
            markerParametersByIDCalls.append(id)
            return markerParametersByID[id]
        }

        func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? {
            let key = coordinateKey(coordinate)
            markerParametersByCoordinateCalls.append(key)
            return markerParametersByCoordinate[key]
        }

        func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
            markerParametersByEntityKeyCalls.append(key)
            return markerParametersByEntityKey[key]
        }

        func markerParametersForBackup() async -> [MarkerParameters] {
            markerParametersForBackupCalls += 1
            return markerParametersToReturn
        }

        func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
            referenceByEntityKeyCalls.append(key)
            return referenceByEntityKey[key]?.domainEntity
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

        func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData? {
            nil
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

    private final class MockSpatialWriteContract: SpatialWriteContract {
        var markerIDsByEntityKey: [String: String] = [:]
        var nextTemporaryID = "temp-marker-id"
        private(set) var addRouteCalls: [String] = []
        private(set) var deleteRouteCalls: [String] = []
        private(set) var updateRouteCalls: [String] = []
        private(set) var addReferenceEntityByEntityKeyCalls: [String] = []
        private(set) var addReferenceEntityByLocationCalls: [String] = []
        private(set) var updateReferenceEntityCalls: [String] = []
        private(set) var removeReferenceEntityCalls: [String] = []

        func addRoute(_ route: Route) async throws {
            addRouteCalls.append(route.id)
        }

        func deleteRoute(id: String) async throws {
            deleteRouteCalls.append(id)
        }

        func updateRoute(_ route: Route) async throws {
            updateRouteCalls.append(route.id)
        }

        func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
            addReferenceEntityByEntityKeyCalls.append(entityKey)
            return markerIDsByEntityKey[entityKey] ?? nextTemporaryID
        }

        func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
            let coordinate = location.location.coordinate
            addReferenceEntityByLocationCalls.append("\(coordinate.latitude),\(coordinate.longitude)")
            return nextTemporaryID
        }

        func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws {
            updateReferenceEntityCalls.append(id)
        }

        func removeReferenceEntity(id: String) async throws {
            removeReferenceEntityCalls.append(id)
        }
    }

    private final class MockSpatialMaintenanceWriteContract: SpatialMaintenanceWriteContract {
        private(set) var importRouteFromCloudCalls: [String] = []
        private(set) var importReferenceEntityFromCloudCalls: [String?] = []
        private(set) var removeAllReferenceEntitiesCalls = 0
        private(set) var removeAllRoutesCalls = 0
        private(set) var clearNewReferenceEntitiesAndRoutesCalls = 0
        private(set) var restoreCachedAddressCounts: [Int] = []
        private(set) var cleanCorruptReferenceEntitiesCalls = 0

        func importRouteFromCloud(_ route: Route) async throws {
            importRouteFromCloudCalls.append(route.id)
        }

        func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws {
            importReferenceEntityFromCloudCalls.append(markerParameters.id)
        }

        func removeAllReferenceEntities() async throws {
            removeAllReferenceEntitiesCalls += 1
        }

        func removeAllRoutes() async throws {
            removeAllRoutesCalls += 1
        }

        func clearNewReferenceEntitiesAndRoutes() async throws {
            clearNewReferenceEntitiesAndRoutesCalls += 1
        }

        func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws {
            restoreCachedAddressCounts.append(addresses.count)
        }

        func cleanCorruptReferenceEntities() async throws {
            cleanCorruptReferenceEntitiesCalls += 1
        }
    }

    override func tearDown() {
        DataContractRegistry.resetForTesting()
        super.tearDown()
    }

    func testSpatialReadDispatchesToConfiguredContract() async {
        let mock = MockSpatialReadContract()
        var route = Route()
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
        XCTAssertTrue(DataContractRegistry.spatialMaintenanceWrite is RealmSpatialMaintenanceWriteContract)

        DataContractRegistry.resetForTesting()

        XCTAssertTrue(DataContractRegistry.spatialRead is RealmSpatialReadContract)
        XCTAssertTrue(DataContractRegistry.spatialWrite is RealmSpatialWriteContract)
        XCTAssertTrue(DataContractRegistry.spatialMaintenanceWrite is RealmSpatialMaintenanceWriteContract)
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

    func testSpatialWriteAsyncDispatchesToConfiguredContract() async throws {
        let readMock = MockSpatialReadContract()
        let writeMock = MockSpatialWriteContract()
        let maintenanceMock = MockSpatialMaintenanceWriteContract()
        writeMock.markerIDsByEntityKey["entity-1"] = "marker-1"
        writeMock.nextTemporaryID = "temp-marker-id"
        var route = Route()
        route.id = "route-async-1"

        DataContractRegistry.configure(spatialRead: readMock,
                                       spatialWrite: writeMock,
                                       spatialMaintenanceWrite: maintenanceMock)

        try await DataContractRegistry.spatialWrite.addRoute(route)
        try await DataContractRegistry.spatialMaintenanceWrite.importRouteFromCloud(route)
        try await DataContractRegistry.spatialMaintenanceWrite.importReferenceEntityFromCloud(markerParameters: MarkerParameters(name: "Marker Import",
                                                                                                                                  latitude: 47.62,
                                                                                                                                  longitude: -122.35),
                                                                                              entity: GenericLocation(lat: 47.62,
                                                                                                                      lon: -122.35))
        var updatedRoute = route
        updatedRoute.name = "Updated Route"
        updatedRoute.routeDescription = "Updated Description"
        try await DataContractRegistry.spatialWrite.updateRoute(updatedRoute)
        try await DataContractRegistry.spatialWrite.deleteRoute(id: route.id)
        let markerFromEntity = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: "entity-1",
                                                                                               nickname: "Test",
                                                                                               estimatedAddress: "123 Main",
                                                                                               annotation: nil)
        let markerFromLocation = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: GenericLocation(lat: 47.62,
                                                                                                         lon: -122.35),
                                                                                                nickname: "Nearby",
                                                                                                estimatedAddress: "1st Ave",
                                                                                                annotation: nil)
        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: markerFromEntity,
                                                                          location: SSGeoCoordinate(latitude: 47.62, longitude: -122.35),
                                                                          nickname: "Updated",
                                                                          estimatedAddress: "1st Ave",
                                                                          annotation: nil)
        try await DataContractRegistry.spatialMaintenanceWrite.removeAllReferenceEntities()
        try await DataContractRegistry.spatialMaintenanceWrite.removeAllRoutes()
        try await DataContractRegistry.spatialMaintenanceWrite.clearNewReferenceEntitiesAndRoutes()
        let firstAddress = AddressCacheRecord(key: "address-1",
                                              lastSelectedDate: nil,
                                              name: "Address 1",
                                              addressLine: "1 Main",
                                              streetName: "Main",
                                              latitude: 47.62,
                                              longitude: -122.35,
                                              centroidLatitude: 47.62,
                                              centroidLongitude: -122.35,
                                              searchString: nil)
        let secondAddress = AddressCacheRecord(key: "address-2",
                                               lastSelectedDate: nil,
                                               name: "Address 2",
                                               addressLine: "2 Main",
                                               streetName: "Main",
                                               latitude: 47.63,
                                               longitude: -122.36,
                                               centroidLatitude: 47.63,
                                               centroidLongitude: -122.36,
                                               searchString: nil)
        try await DataContractRegistry.spatialMaintenanceWrite.restoreCachedAddresses([firstAddress, secondAddress])
        try await DataContractRegistry.spatialMaintenanceWrite.cleanCorruptReferenceEntities()
        try await DataContractRegistry.spatialWrite.removeReferenceEntity(id: markerFromEntity)

        XCTAssertEqual(markerFromEntity, "marker-1")
        XCTAssertEqual(markerFromLocation, "temp-marker-id")
        XCTAssertEqual(writeMock.addRouteCalls, [route.id])
        XCTAssertEqual(maintenanceMock.importRouteFromCloudCalls, [route.id])
        XCTAssertEqual(maintenanceMock.importReferenceEntityFromCloudCalls.count, 1)
        XCTAssertEqual(writeMock.updateRouteCalls, [route.id])
        XCTAssertEqual(writeMock.deleteRouteCalls, [route.id])
        XCTAssertEqual(writeMock.addReferenceEntityByEntityKeyCalls, ["entity-1"])
        XCTAssertEqual(writeMock.addReferenceEntityByLocationCalls, ["47.62,-122.35"])
        XCTAssertEqual(writeMock.updateReferenceEntityCalls, ["marker-1"])
        XCTAssertEqual(maintenanceMock.removeAllReferenceEntitiesCalls, 1)
        XCTAssertEqual(maintenanceMock.removeAllRoutesCalls, 1)
        XCTAssertEqual(maintenanceMock.clearNewReferenceEntitiesAndRoutesCalls, 1)
        XCTAssertEqual(maintenanceMock.restoreCachedAddressCounts, [2])
        XCTAssertEqual(maintenanceMock.cleanCorruptReferenceEntitiesCalls, 1)
        XCTAssertEqual(writeMock.removeReferenceEntityCalls, ["marker-1"])
    }

    func testDefaultSpatialMaintenanceWriteImportHydratesFirstWaypointFromConfiguredAsyncRead() async throws {
        let readMock = MockSpatialReadContract()
        let markerID = "contract-read-marker-\(UUID().uuidString)"
        let markerCoordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let fallbackCoordinate = CLLocationCoordinate2D(latitude: 10.0, longitude: 20.0)
        let marker = RealmReferenceEntity(coordinate: markerCoordinate)
        marker.id = markerID
        readMock.referenceByID[markerID] = marker

        DataContractRegistry.configure(spatialRead: readMock)

        let imported = ImportedLocationDetail(nickname: "Imported Waypoint", annotation: "Fallback Coordinate")
        let importedDetail = LocationDetail(location: CLLocation(latitude: fallbackCoordinate.latitude,
                                                                 longitude: fallbackCoordinate.longitude),
                                            imported: imported,
                                            telemetryContext: nil)
        let waypoint = RouteWaypoint(index: 0, markerId: markerID, importedLocationDetail: importedDetail)
        let routeID = "contract-read-route-\(UUID().uuidString)"
        var route = Route()
        route.id = routeID
        route.name = "Contract Read Hydration"
        route.waypoints = [waypoint]

        defer {
            deletePersistedRouteIfPresent(id: routeID)
        }

        try await DataContractRegistry.spatialMaintenanceWrite.importRouteFromCloud(route)

        guard let persistedRoute = Route.object(forPrimaryKey: routeID) else {
            XCTFail("Expected imported route to be persisted")
            return
        }

        XCTAssertEqual(readMock.referenceByIDCalls, [markerID])
        XCTAssertEqual(persistedRoute.firstWaypointLatitude ?? 0, markerCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(persistedRoute.firstWaypointLongitude ?? 0, markerCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertNotEqual(persistedRoute.firstWaypointLatitude ?? 0, fallbackCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertNotEqual(persistedRoute.firstWaypointLongitude ?? 0, fallbackCoordinate.longitude, accuracy: 0.000_001)
    }

    private func deletePersistedRouteIfPresent(id: String) {
        guard let database = try? RealmHelper.getDatabaseRealm(),
              let route = database.object(ofType: RealmRoute.self, forPrimaryKey: id) else {
            return
        }

        try? database.write {
            database.delete(route)
        }
    }
}

@MainActor
private final class InMemorySpatialContractStore: SpatialReadContract, SpatialWriteContract, SpatialMaintenanceWriteContract {
    private var routesByID: [String: Route] = [:]
    private var referenceByID: [String: ReferenceEntity] = [:]
    private var referenceIDByEntityKey: [String: String] = [:]
    private var addressCacheRecords: [AddressCacheRecord] = []
    private var poiByEntityKey: [String: POI] = [:]

    var restoredAddressCount: Int {
        addressCacheRecords.count
    }

    // MARK: - Route Reads

    func routes() async -> [Route] {
        routesByID.values.sorted(by: { $0.id < $1.id })
    }

    func route(byKey key: String) async -> Route? {
        routesByID[key]
    }

    func routeMetadata(byKey key: String) async -> RouteReadMetadata? {
        guard let route = routesByID[key] else {
            return nil
        }

        return RouteReadMetadata(id: route.id, lastUpdatedDate: route.lastUpdatedDate)
    }

    func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? {
        guard let route = routesByID[key] else {
            return nil
        }

        return RouteParameters(route: route, context: context)
    }

    func routeParametersForBackup() async -> [RouteParameters] {
        routesByID.values
            .sorted(by: { $0.id < $1.id })
            .compactMap { RouteParameters(route: $0, context: .backup) }
    }

    func routes(containingMarkerID markerID: String) async -> [Route] {
        routesByID.values
            .filter { route in
                route.waypoints.contains(where: { $0.markerId == markerID })
            }
            .sorted(by: { $0.id < $1.id })
    }

    // MARK: - Reference Reads

    func referenceEntity(byID id: String) async -> ReferenceEntity? {
        referenceByID[id]
    }

    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? {
        guard let reference = referenceByID[id] else {
            return nil
        }

        let superCategory = reference.entityKey
            .flatMap { poiByEntityKey[$0]?.superCategory } ?? "undefined"
        return ReferenceCalloutReadData(name: displayName(for: reference), superCategory: superCategory)
    }

    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
        guard let reference = referenceByID[id] else {
            return nil
        }

        return SSGeoMath.distanceMeters(from: location.coordinate, to: reference.coordinate)
    }

    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? {
        guard let reference = referenceByID[id] else {
            return nil
        }

        return ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
    }

    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? {
        guard let id = referenceIDByEntityKey[key], let reference = referenceByID[id] else {
            return nil
        }

        return ReferenceReadMetadata(id: reference.id, lastUpdatedDate: reference.lastUpdatedDate)
    }

    func markerParameters(byID id: String) async -> MarkerParameters? {
        guard let reference = referenceByID[id] else {
            return nil
        }

        return MarkerParameters(name: displayName(for: reference),
                                latitude: reference.latitude,
                                longitude: reference.longitude)
    }

    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? {
        guard let reference = referenceByID.values.first(where: { $0.coordinate == coordinate }) else {
            return nil
        }

        return MarkerParameters(name: displayName(for: reference),
                                latitude: reference.latitude,
                                longitude: reference.longitude)
    }

    func markerParameters(byEntityKey key: String) async -> MarkerParameters? {
        guard let id = referenceIDByEntityKey[key], let reference = referenceByID[id] else {
            return nil
        }

        return MarkerParameters(name: displayName(for: reference),
                                latitude: reference.latitude,
                                longitude: reference.longitude)
    }

    func markerParametersForBackup() async -> [MarkerParameters] {
        referenceByID.values
            .sorted(by: { $0.id < $1.id })
            .map {
                MarkerParameters(name: displayName(for: $0),
                                 latitude: $0.latitude,
                                 longitude: $0.longitude)
            }
    }

    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
        guard let id = referenceIDByEntityKey[key] else {
            return nil
        }

        return referenceByID[id]
    }

    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? {
        referenceByID.values.first(where: { $0.coordinate == coordinate })
    }

    func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
        let coordinate = location.location.coordinate.ssGeoCoordinate
        return referenceByID.values.first(where: { $0.coordinate == coordinate })
    }

    func referenceEntities() async -> [ReferenceEntity] {
        referenceByID.values.sorted(by: { $0.id < $1.id })
    }

    func recentlySelectedPOIs() async -> [POI] {
        []
    }

    func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData? {
        nil
    }

    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] {
        referenceByID.values
            .filter { reference in
                SSGeoMath.distanceMeters(from: reference.coordinate, to: coordinate) <= rangeMeters
            }
            .sorted(by: { $0.id < $1.id })
    }

    func poi(byKey key: String) async -> POI? {
        poiByEntityKey[key]
    }

    // MARK: - Graph Reads

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
        []
    }

    // MARK: - Tile Reads

    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> {
        []
    }

    func tileData(for tiles: [VectorTile]) async -> [TileData] {
        []
    }

    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] {
        let maxRange = rangeMeters ?? .greatestFiniteMagnitude

        return referenceByID.values.compactMap { reference in
            let distance = SSGeoMath.distanceMeters(from: location.coordinate, to: reference.coordinate)
            guard distance <= maxRange else {
                return nil
            }

            return GenericLocation(ref: reference)
        }
    }

    // MARK: - Writes

    func addRoute(_ route: Route) async throws {
        if let existingRoute = routesByID[route.id] {
            routesByID[route.id] = updatedRouteSnapshot(existing: existingRoute,
                                                        incoming: route,
                                                        updatedAt: Date())
            return
        }

        routesByID[route.id] = routeSnapshot(route)
    }

    func deleteRoute(id: String) async throws {
        routesByID.removeValue(forKey: id)
    }

    func updateRoute(_ route: Route) async throws {
        guard let existingRoute = routesByID[route.id] else {
            throw RouteRealmError.doesNotExist
        }

        routesByID[route.id] = updatedRouteSnapshot(existing: existingRoute,
                                                    incoming: route,
                                                    updatedAt: Date())
    }

    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
        if let existingID = referenceIDByEntityKey[entityKey], let existing = referenceByID[existingID] {
            let updated = makeReferenceEntity(id: existing.id,
                                              entityKey: entityKey,
                                              coordinate: existing.coordinate,
                                              nickname: nickname ?? existing.nickname,
                                              estimatedAddress: estimatedAddress ?? existing.estimatedAddress,
                                              annotation: annotation ?? existing.annotation,
                                              isTemp: existing.isTemp)
            store(updated)
            return updated.id
        }

        let reference = makeReferenceEntity(id: UUID().uuidString,
                                            entityKey: entityKey,
                                            coordinate: SSGeoCoordinate(latitude: 0, longitude: 0),
                                            nickname: nickname,
                                            estimatedAddress: estimatedAddress,
                                            annotation: annotation,
                                            isTemp: false)
        store(reference)
        return reference.id
    }

    func addReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String {
        let reference = makeReferenceEntity(id: UUID().uuidString,
                                            entityKey: nil,
                                            coordinate: location.location.coordinate.ssGeoCoordinate,
                                            nickname: nickname,
                                            estimatedAddress: estimatedAddress,
                                            annotation: annotation,
                                            isTemp: false)
        store(reference)
        return reference.id
    }

    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws {
        guard let existing = referenceByID[id] else {
            return
        }

        let updated = makeReferenceEntity(id: id,
                                          entityKey: existing.entityKey,
                                          coordinate: location ?? existing.coordinate,
                                          nickname: nickname ?? existing.nickname,
                                          estimatedAddress: estimatedAddress ?? existing.estimatedAddress,
                                          annotation: annotation ?? existing.annotation,
                                          isTemp: false)
        store(updated)
    }

    func removeAllReferenceEntities() async throws {
        referenceByID.removeAll()
        referenceIDByEntityKey.removeAll()
        poiByEntityKey.removeAll()
    }

    func importRouteFromCloud(_ route: Route) async throws {
        routesByID[route.id] = routeSnapshot(route)
    }

    func importReferenceEntityFromCloud(markerParameters: MarkerParameters, entity: POI) async throws {
        guard let markerID = markerParameters.id else {
            return
        }

        let reference = makeReferenceEntity(id: markerID,
                                            entityKey: entity.key,
                                            coordinate: SSGeoCoordinate(latitude: markerParameters.location.coordinate.latitude,
                                                                        longitude: markerParameters.location.coordinate.longitude),
                                            nickname: markerParameters.nickname,
                                            estimatedAddress: markerParameters.estimatedAddress,
                                            annotation: markerParameters.annotation,
                                            isTemp: false)
        store(reference)
    }

    func removeAllRoutes() async throws {
        routesByID.removeAll()
    }

    func clearNewReferenceEntitiesAndRoutes() async throws {
        routesByID = Dictionary(uniqueKeysWithValues: routesByID.map { key, route in
            var clearedRoute = route
            clearedRoute.isNew = false
            return (key, clearedRoute)
        })

        referenceByID = Dictionary(uniqueKeysWithValues: referenceByID.map { key, reference in
            let clearedReference = ReferenceEntity(id: reference.id,
                                                   entityKey: reference.entityKey,
                                                   lastUpdatedDate: reference.lastUpdatedDate,
                                                   lastSelectedDate: reference.lastSelectedDate,
                                                   isNew: false,
                                                   isTemp: reference.isTemp,
                                                   coordinate: reference.coordinate,
                                                   nickname: reference.nickname,
                                                   estimatedAddress: reference.estimatedAddress,
                                                   annotation: reference.annotation)
            return (key, clearedReference)
        })
    }

    func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws {
        addressCacheRecords = addresses
    }

    func cleanCorruptReferenceEntities() async throws {
        let validReferences = referenceByID.values.filter {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude).isValidLocationCoordinate
        }

        referenceByID = Dictionary(uniqueKeysWithValues: validReferences.map { ($0.id, $0) })
        referenceIDByEntityKey = Dictionary(uniqueKeysWithValues: validReferences.compactMap {
            guard let entityKey = $0.entityKey else {
                return nil
            }
            return (entityKey, $0.id)
        })
        poiByEntityKey = Dictionary(uniqueKeysWithValues: validReferences.compactMap { reference in
            guard let entityKey = reference.entityKey else {
                return nil
            }

            let poi = GenericLocation(coordinate: reference.coordinate,
                                      name: reference.nickname ?? "",
                                      address: reference.estimatedAddress)
            poi.key = entityKey
            return (entityKey, poi)
        })
    }

    func removeReferenceEntity(id: String) async throws {
        if let removed = referenceByID.removeValue(forKey: id), let entityKey = removed.entityKey {
            referenceIDByEntityKey.removeValue(forKey: entityKey)
            poiByEntityKey.removeValue(forKey: entityKey)
        }
    }

    // MARK: - Helpers

    private func makeReferenceEntity(id: String,
                                     entityKey: String?,
                                     coordinate: SSGeoCoordinate,
                                     nickname: String?,
                                     estimatedAddress: String?,
                                     annotation: String?,
                                     isTemp: Bool) -> ReferenceEntity {
        ReferenceEntity(id: id,
                        entityKey: entityKey,
                        lastUpdatedDate: Date(),
                        lastSelectedDate: nil,
                        isNew: false,
                        isTemp: isTemp,
                        coordinate: coordinate,
                        nickname: nickname,
                        estimatedAddress: estimatedAddress,
                        annotation: annotation)
    }

    private func store(_ reference: ReferenceEntity) {
        referenceByID[reference.id] = reference

        guard let entityKey = reference.entityKey else {
            return
        }

        referenceIDByEntityKey[entityKey] = reference.id
        let poi = GenericLocation(coordinate: reference.coordinate,
                                  name: reference.nickname ?? "",
                                  address: reference.estimatedAddress)
        poi.key = entityKey
        poiByEntityKey[entityKey] = poi
    }

    private func displayName(for reference: ReferenceEntity) -> String {
        if let nickname = reference.nickname, nickname.isEmpty == false {
            return nickname
        }

        if let estimatedAddress = reference.estimatedAddress, estimatedAddress.isEmpty == false {
            return estimatedAddress
        }

        return "Marker"
    }

    private func routeSnapshot(_ route: Route) -> Route {
        var snapshot = route
        applyFirstWaypointCoordinate(to: &snapshot, waypoints: route.waypoints)
        return snapshot
    }

    private func updatedRouteSnapshot(existing: Route, incoming: Route, updatedAt: Date) -> Route {
        var updated = existing
        updated.name = incoming.name
        updated.routeDescription = incoming.routeDescription
        updated.waypoints = incoming.waypoints
        updated.lastUpdatedDate = updatedAt
        applyFirstWaypointCoordinate(to: &updated, waypoints: incoming.waypoints)
        return updated
    }

    private func applyFirstWaypointCoordinate(to route: inout Route, waypoints: [RouteWaypoint]) {
        guard let firstWaypointCoordinate = firstWaypointCoordinate(for: waypoints) else {
            route.firstWaypointLatitude = nil
            route.firstWaypointLongitude = nil
            return
        }

        route.firstWaypointLatitude = firstWaypointCoordinate.latitude
        route.firstWaypointLongitude = firstWaypointCoordinate.longitude
    }

    private func firstWaypointCoordinate(for waypoints: [RouteWaypoint]) -> SSGeoCoordinate? {
        guard let firstWaypoint = waypoints.ordered.first else {
            return nil
        }

        if let markerCoordinate = referenceByID[firstWaypoint.markerId]?.coordinate {
            return markerCoordinate
        }

        return firstWaypoint.asLocationDetail?.location.coordinate.ssGeoCoordinate
    }
}

@MainActor
final class InMemorySpatialContractStoreTests: XCTestCase {
    override func tearDown() {
        DataContractRegistry.resetForTesting()
        super.tearDown()
    }

    func testRouteRoundTripWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        var route = Route()
        route.id = "route-in-memory-1"
        route.name = "In Memory Route"
        route.routeDescription = "Initial"

        try await DataContractRegistry.spatialWrite.addRoute(route)
        let initialRoutes = await DataContractRegistry.spatialRead.routes()
        let initialRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)
        XCTAssertEqual(initialRoutes.count, 1)
        XCTAssertEqual(initialRoute?.name, "In Memory Route")

        var updatedRoute = route
        updatedRoute.name = "Updated Route"
        updatedRoute.routeDescription = "Updated Description"
        try await DataContractRegistry.spatialWrite.updateRoute(updatedRoute)
        let persistedUpdatedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)
        let routeMetadata = await DataContractRegistry.spatialRead.routeMetadata(byKey: route.id)
        let routeParameters = await DataContractRegistry.spatialRead.routeParametersForBackup()
        XCTAssertEqual(persistedUpdatedRoute?.name, "Updated Route")
        XCTAssertEqual(routeMetadata?.id, route.id)
        XCTAssertEqual(routeParameters.count, 1)

        try await DataContractRegistry.spatialWrite.deleteRoute(id: route.id)
        let deletedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)
        let routesAfterDelete = await DataContractRegistry.spatialRead.routes()
        XCTAssertNil(deletedRoute)
        XCTAssertTrue(routesAfterDelete.isEmpty)
    }

    func testRouteWriteContractParityAcrossAddUpdateAndImportWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        var route = Route()
        route.id = "route-write-parity-1"
        route.name = "Initial Route"
        route.routeDescription = "Initial Description"
        route.createdDate = Date(timeIntervalSince1970: 1_000)
        route.lastSelectedDate = Date(timeIntervalSince1970: 1_100)
        route.lastUpdatedDate = Date(timeIntervalSince1970: 1_200)

        try await DataContractRegistry.spatialWrite.addRoute(route)

        var importedRoute = route
        importedRoute.name = "Cloud Route"
        importedRoute.routeDescription = "Cloud Description"
        importedRoute.createdDate = Date(timeIntervalSince1970: 2_000)
        importedRoute.lastSelectedDate = Date(timeIntervalSince1970: 2_100)
        importedRoute.lastUpdatedDate = Date(timeIntervalSince1970: 2_200)
        try await DataContractRegistry.spatialMaintenanceWrite.importRouteFromCloud(importedRoute)

        guard let cloudPersistedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id) else {
            XCTFail("Expected imported route to be persisted")
            return
        }
        XCTAssertEqual(cloudPersistedRoute.name, "Cloud Route")
        XCTAssertEqual(cloudPersistedRoute.routeDescription, "Cloud Description")
        XCTAssertEqual(cloudPersistedRoute.createdDate, importedRoute.createdDate)
        XCTAssertEqual(cloudPersistedRoute.lastSelectedDate, importedRoute.lastSelectedDate)
        XCTAssertEqual(cloudPersistedRoute.lastUpdatedDate, importedRoute.lastUpdatedDate)

        var localUpdateRoute = importedRoute
        localUpdateRoute.name = "Local Updated Route"
        localUpdateRoute.routeDescription = "Local Updated Description"
        localUpdateRoute.createdDate = Date(timeIntervalSince1970: 3_000)
        localUpdateRoute.lastSelectedDate = Date(timeIntervalSince1970: 3_100)
        localUpdateRoute.lastUpdatedDate = Date(timeIntervalSince1970: 3_200)
        let localUpdateStart = Date()
        try await DataContractRegistry.spatialWrite.updateRoute(localUpdateRoute)
        let localUpdateEnd = Date()

        guard let localUpdatedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id) else {
            XCTFail("Expected local update route to be persisted")
            return
        }
        XCTAssertEqual(localUpdatedRoute.name, "Local Updated Route")
        XCTAssertEqual(localUpdatedRoute.routeDescription, "Local Updated Description")
        XCTAssertEqual(localUpdatedRoute.createdDate, importedRoute.createdDate)
        XCTAssertEqual(localUpdatedRoute.lastSelectedDate, importedRoute.lastSelectedDate)
        XCTAssertGreaterThanOrEqual(localUpdatedRoute.lastUpdatedDate, localUpdateStart)
        XCTAssertLessThanOrEqual(localUpdatedRoute.lastUpdatedDate, localUpdateEnd)

        var existingAddRoute = localUpdateRoute
        existingAddRoute.name = "Add Existing Route"
        existingAddRoute.routeDescription = "Add Existing Description"
        existingAddRoute.createdDate = Date(timeIntervalSince1970: 4_000)
        existingAddRoute.lastSelectedDate = Date(timeIntervalSince1970: 4_100)
        existingAddRoute.lastUpdatedDate = Date(timeIntervalSince1970: 4_200)
        let addExistingStart = Date()
        try await DataContractRegistry.spatialWrite.addRoute(existingAddRoute)
        let addExistingEnd = Date()

        guard let addUpdatedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id) else {
            XCTFail("Expected add(existing) route update to be persisted")
            return
        }
        XCTAssertEqual(addUpdatedRoute.name, "Add Existing Route")
        XCTAssertEqual(addUpdatedRoute.routeDescription, "Add Existing Description")
        XCTAssertEqual(addUpdatedRoute.createdDate, importedRoute.createdDate)
        XCTAssertEqual(addUpdatedRoute.lastSelectedDate, importedRoute.lastSelectedDate)
        XCTAssertGreaterThanOrEqual(addUpdatedRoute.lastUpdatedDate, addExistingStart)
        XCTAssertLessThanOrEqual(addUpdatedRoute.lastUpdatedDate, addExistingEnd)
    }

    func testRouteWritesHydrateFirstWaypointCoordinateAcrossAddUpdateAndImportWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        let firstMarkerLocation = GenericLocation(lat: 47.6205, lon: -122.3493)
        let secondMarkerLocation = GenericLocation(lat: 47.6301, lon: -122.3402)
        let firstMarkerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: firstMarkerLocation,
                                                                                            nickname: "First Marker",
                                                                                            estimatedAddress: nil,
                                                                                            annotation: nil)
        let secondMarkerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: secondMarkerLocation,
                                                                                             nickname: "Second Marker",
                                                                                             estimatedAddress: nil,
                                                                                             annotation: nil)

        var firstWaypoint = RouteWaypoint()
        firstWaypoint.index = 0
        firstWaypoint.markerId = firstMarkerID

        var secondWaypoint = RouteWaypoint()
        secondWaypoint.index = 1
        secondWaypoint.markerId = secondMarkerID

        var route = Route()
        route.id = "route-waypoint-coordinate-parity"
        route.name = "Waypoint Coordinate Route"
        route.waypoints = [firstWaypoint, secondWaypoint]
        route.firstWaypointLatitude = nil
        route.firstWaypointLongitude = nil

        try await DataContractRegistry.spatialWrite.addRoute(route)

        guard let addedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id) else {
            XCTFail("Expected added route to be persisted")
            return
        }
        XCTAssertEqual(addedRoute.firstWaypointLatitude ?? 0, firstMarkerLocation.location.coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(addedRoute.firstWaypointLongitude ?? 0, firstMarkerLocation.location.coordinate.longitude, accuracy: 0.000_001)

        firstWaypoint.index = 1
        secondWaypoint.index = 0
        var updatedRoute = route
        updatedRoute.waypoints = [secondWaypoint, firstWaypoint]
        updatedRoute.firstWaypointLatitude = nil
        updatedRoute.firstWaypointLongitude = nil
        try await DataContractRegistry.spatialWrite.updateRoute(updatedRoute)

        guard let locallyUpdatedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id) else {
            XCTFail("Expected locally updated route to be persisted")
            return
        }
        XCTAssertEqual(locallyUpdatedRoute.firstWaypointLatitude ?? 0, secondMarkerLocation.location.coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(locallyUpdatedRoute.firstWaypointLongitude ?? 0, secondMarkerLocation.location.coordinate.longitude, accuracy: 0.000_001)

        var importedRoute = route
        importedRoute.waypoints = [firstWaypoint, secondWaypoint]
        importedRoute.firstWaypointLatitude = 0
        importedRoute.firstWaypointLongitude = 0
        try await DataContractRegistry.spatialMaintenanceWrite.importRouteFromCloud(importedRoute)

        guard let cloudImportedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id) else {
            XCTFail("Expected cloud imported route to be persisted")
            return
        }
        XCTAssertEqual(cloudImportedRoute.firstWaypointLatitude ?? 0, secondMarkerLocation.location.coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(cloudImportedRoute.firstWaypointLongitude ?? 0, secondMarkerLocation.location.coordinate.longitude, accuracy: 0.000_001)
    }

    func testMarkerReadWriteAndRangeQueriesWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        let nearLocation = GenericLocation(lat: 47.6205, lon: -122.3493)
        let farLocation = GenericLocation(lat: 47.7010, lon: -122.3500)

        let nearID = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: nearLocation,
                                                                                     nickname: "Near",
                                                                                     estimatedAddress: "Near Address",
                                                                                     annotation: nil)
        let farID = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: farLocation,
                                                                                    nickname: "Far",
                                                                                    estimatedAddress: "Far Address",
                                                                                    annotation: nil)

        let nearby = await DataContractRegistry.spatialRead.referenceEntities(near: SSGeoCoordinate(latitude: 47.6205,
                                                                                                     longitude: -122.3493),
                                                                              rangeMeters: 100)
        XCTAssertTrue(nearby.contains(where: { $0.id == nearID }))
        XCTAssertFalse(nearby.contains(where: { $0.id == farID }))

        let distance = await DataContractRegistry.spatialRead.distanceToClosestLocation(forMarkerID: nearID,
                                                                                        from: SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 47.6205,
                                                                                                                                         longitude: -122.3493)))
        XCTAssertEqual(distance ?? -1, 0, accuracy: 0.1)
        let markerParameters = await DataContractRegistry.spatialRead.markerParameters(byID: nearID)
        XCTAssertNotNil(markerParameters)

        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: nearID,
                                                                          location: nil,
                                                                          nickname: "Near Updated",
                                                                          estimatedAddress: nil,
                                                                          annotation: nil)
        let updatedReference = await DataContractRegistry.spatialRead.referenceEntity(byID: nearID)
        XCTAssertEqual(updatedReference?.nickname, "Near Updated")

        try await DataContractRegistry.spatialWrite.removeReferenceEntity(id: nearID)
        let removedTemporaryReference = await DataContractRegistry.spatialRead.referenceEntity(byID: nearID)
        let retainedReference = await DataContractRegistry.spatialRead.referenceEntity(byID: farID)
        XCTAssertNil(removedTemporaryReference)
        XCTAssertNotNil(retainedReference)
    }

    func testRouteContainsMarkerAndAddressRestoreWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        let markerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: "entity-marker-1",
                                                                                       nickname: "Marker",
                                                                                       estimatedAddress: "Marker Address",
                                                                                       annotation: nil)
        var waypoint = RouteWaypoint()
        waypoint.index = 0
        waypoint.markerId = markerID

        var route = Route()
        route.id = "route-with-marker"
        route.name = "Marker Route"
        route.waypoints.append(waypoint)
        try await DataContractRegistry.spatialWrite.addRoute(route)

        let containing = await DataContractRegistry.spatialRead.routes(containingMarkerID: markerID)
        XCTAssertEqual(containing.map(\.id), ["route-with-marker"])

        let firstAddress = AddressCacheRecord(key: "address-1",
                                              lastSelectedDate: nil,
                                              name: "Address 1",
                                              addressLine: "1 Main",
                                              streetName: "Main",
                                              latitude: 47.62,
                                              longitude: -122.35,
                                              centroidLatitude: 47.62,
                                              centroidLongitude: -122.35,
                                              searchString: nil)
        let secondAddress = AddressCacheRecord(key: "address-2",
                                               lastSelectedDate: nil,
                                               name: "Address 2",
                                               addressLine: "2 Main",
                                               streetName: "Main",
                                               latitude: 47.63,
                                               longitude: -122.36,
                                               centroidLatitude: 47.63,
                                               centroidLongitude: -122.36,
                                               searchString: nil)
        try await DataContractRegistry.spatialMaintenanceWrite.restoreCachedAddresses([firstAddress, secondAddress])
        XCTAssertEqual(store.restoredAddressCount, 2)
    }

    func testRouteParametersContextParityWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        let createdDate = Date(timeIntervalSince1970: 10_000)
        let lastUpdatedDate = Date(timeIntervalSince1970: 11_000)
        let lastSelectedDate = Date(timeIntervalSince1970: 12_000)

        var waypoint = RouteWaypoint()
        waypoint.index = 0
        waypoint.markerId = "route-parameter-marker"

        var route = Route()
        route.id = "route-parameter-context"
        route.name = "Route Parameter Context"
        route.routeDescription = "Context parity route"
        route.waypoints = [waypoint]
        route.createdDate = createdDate
        route.lastUpdatedDate = lastUpdatedDate
        route.lastSelectedDate = lastSelectedDate

        try await DataContractRegistry.spatialWrite.addRoute(route)

        let backupParameters = await DataContractRegistry.spatialRead.routeParameters(byKey: route.id, context: .backup)
        let shareParameters = await DataContractRegistry.spatialRead.routeParameters(byKey: route.id, context: .share)

        XCTAssertEqual(backupParameters?.id, route.id)
        XCTAssertEqual(backupParameters?.createdDate, createdDate)
        XCTAssertEqual(backupParameters?.lastUpdatedDate, lastUpdatedDate)
        XCTAssertEqual(backupParameters?.lastSelectedDate, lastSelectedDate)

        XCTAssertEqual(shareParameters?.id, route.id)
        XCTAssertNil(shareParameters?.createdDate)
        XCTAssertNil(shareParameters?.lastUpdatedDate)
        XCTAssertNil(shareParameters?.lastSelectedDate)
    }

    func testReferenceLookupParityAcrossEntityKeyAndCoordinateReadsWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        let coordinate = SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493)
        let genericLocation = GenericLocation(coordinate: coordinate,
                                              name: "Lookup Place",
                                              address: "401 Pine St")
        let locationMarkerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: genericLocation,
                                                                                                nickname: "Lookup Nick",
                                                                                                estimatedAddress: "401 Pine St",
                                                                                                annotation: "North Entrance")
        let entityKey = "lookup-entity-key"
        let entityKeyMarkerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: entityKey,
                                                                                                 nickname: "Entity Nick",
                                                                                                 estimatedAddress: "Entity Address",
                                                                                                 annotation: nil)

        let referenceByID = await DataContractRegistry.spatialRead.referenceEntity(byID: locationMarkerID)
        let referenceByCoordinate = await DataContractRegistry.spatialRead.referenceEntity(byCoordinate: coordinate)
        let referenceByGenericLocation = await DataContractRegistry.spatialRead.referenceEntity(byGenericLocation: genericLocation)
        let markerByCoordinate = await DataContractRegistry.spatialRead.markerParameters(byCoordinate: coordinate)
        let callout = await DataContractRegistry.spatialRead.referenceCallout(byID: locationMarkerID)

        XCTAssertEqual(referenceByID?.id, locationMarkerID)
        XCTAssertEqual(referenceByCoordinate?.id, locationMarkerID)
        XCTAssertEqual(referenceByGenericLocation?.id, locationMarkerID)
        XCTAssertEqual(markerByCoordinate?.location.coordinate.latitude ?? -1, coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(markerByCoordinate?.location.coordinate.longitude ?? -1, coordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(callout?.name, "Lookup Nick")
        XCTAssertEqual(callout?.superCategory, "undefined")

        let referenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: entityKey)
        let markerByEntityKey = await DataContractRegistry.spatialRead.markerParameters(byEntityKey: entityKey)
        let referenceMetadataByEntityKey = await DataContractRegistry.spatialRead.referenceMetadata(byEntityKey: entityKey)
        let poiByEntityKey = await DataContractRegistry.spatialRead.poi(byKey: entityKey)

        XCTAssertEqual(referenceByEntityKey?.id, entityKeyMarkerID)
        XCTAssertEqual(referenceMetadataByEntityKey?.id, entityKeyMarkerID)
        XCTAssertEqual(markerByEntityKey?.location.coordinate.latitude ?? -1, 0, accuracy: 0.000_001)
        XCTAssertEqual(markerByEntityKey?.location.coordinate.longitude ?? -1, 0, accuracy: 0.000_001)
        XCTAssertEqual(poiByEntityKey?.key, entityKey)
    }

    func testClearNewReferenceEntitiesAndRoutesClearsRouteFlagsAndRetainsReferenceReadsWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        var route = Route()
        route.id = "clear-new-route"
        route.name = "Clear New Route"
        route.isNew = true
        try await DataContractRegistry.spatialWrite.addRoute(route)

        let entityKey = "clear-new-entity-key"
        let referenceID = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: entityKey,
                                                                                          nickname: "Marker Before Clear",
                                                                                          estimatedAddress: "1 Main",
                                                                                          annotation: nil)

        try await DataContractRegistry.spatialMaintenanceWrite.clearNewReferenceEntitiesAndRoutes()

        let clearedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)
        let retainedReference = await DataContractRegistry.spatialRead.referenceEntity(byID: referenceID)
        let retainedReferenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: entityKey)

        XCTAssertEqual(clearedRoute?.id, route.id)
        XCTAssertEqual(clearedRoute?.isNew, false)
        XCTAssertEqual(retainedReference?.id, referenceID)
        XCTAssertEqual(retainedReferenceByEntityKey?.id, referenceID)
    }

    func testCleanCorruptReferenceEntitiesRemovesInvalidEntityKeyLookupsWithoutRealmPersistence() async throws {
        let store = InMemorySpatialContractStore()
        DataContractRegistry.configure(spatialRead: store,
                                       spatialWrite: store,
                                       spatialMaintenanceWrite: store)

        let validEntityKey = "clean-valid-entity-key"
        let validReferenceID = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: validEntityKey,
                                                                                               nickname: "Valid Marker",
                                                                                               estimatedAddress: "2 Main",
                                                                                               annotation: nil)

        let corruptEntityKey = "clean-corrupt-entity-key"
        let corruptReferenceID = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: corruptEntityKey,
                                                                                                 nickname: nil,
                                                                                                 estimatedAddress: nil,
                                                                                                 annotation: nil)
        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: corruptReferenceID,
                                                                          location: SSGeoCoordinate(latitude: 120,
                                                                                                    longitude: 220),
                                                                          nickname: nil,
                                                                          estimatedAddress: nil,
                                                                          annotation: nil)

        let corruptReferenceByEntityKeyBeforeClean = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: corruptEntityKey)
        let corruptPOIBeforeClean = await DataContractRegistry.spatialRead.poi(byKey: corruptEntityKey)
        XCTAssertEqual(corruptReferenceByEntityKeyBeforeClean?.id, corruptReferenceID)
        XCTAssertEqual(corruptPOIBeforeClean?.key, corruptEntityKey)

        try await DataContractRegistry.spatialMaintenanceWrite.cleanCorruptReferenceEntities()

        let validReference = await DataContractRegistry.spatialRead.referenceEntity(byID: validReferenceID)
        let validReferenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: validEntityKey)
        let validPOI = await DataContractRegistry.spatialRead.poi(byKey: validEntityKey)
        let removedReference = await DataContractRegistry.spatialRead.referenceEntity(byID: corruptReferenceID)
        let removedReferenceByEntityKey = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: corruptEntityKey)
        let removedPOI = await DataContractRegistry.spatialRead.poi(byKey: corruptEntityKey)

        XCTAssertEqual(validReference?.id, validReferenceID)
        XCTAssertEqual(validReferenceByEntityKey?.id, validReferenceID)
        XCTAssertEqual(validPOI?.key, validEntityKey)
        XCTAssertNil(removedReference)
        XCTAssertNil(removedReferenceByEntityKey)
        XCTAssertNil(removedPOI)
    }
}
