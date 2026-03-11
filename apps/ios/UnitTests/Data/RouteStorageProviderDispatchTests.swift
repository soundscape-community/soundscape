//
//  RouteStorageProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import MapKit
import SSGeo
@testable import Soundscape

@MainActor
final class RouteStorageProviderDispatchTests: XCTestCase {
    final class MockSpatialReadContract: SpatialReadContract {
        var routesToReturn: [Route] = []
        var routesByKey: [String: Route] = [:]
        var routesContainingByMarkerID: [String: [Route]] = [:]
        var distancesByMarkerID: [String: Double] = [:]
        var poisByKey: [String: POI] = [:]
        var referenceEntitiesByID: [String: ReferenceEntity] = [:]
        var referenceEntitiesByEntityKey: [String: ReferenceEntity] = [:]
        var referenceEntitiesByGenericLocation: [String: ReferenceEntity] = [:]
        private(set) var routesCallCount = 0
        private(set) var routeByKeyCalls: [String] = []
        private(set) var routesContainingMarkerIDCalls: [String] = []
        private(set) var distanceToClosestLocationCallIDs: [String] = []
        private(set) var poiByKeyCalls: [String] = []
        private(set) var referenceEntityByIDCalls: [String] = []
        private(set) var referenceEntityByEntityKeyCalls: [String] = []
        private(set) var referenceEntityByGenericLocationCalls: [String] = []

        func routes() async -> [Route] {
            routesCallCount += 1
            return routesToReturn
        }
        func route(byKey key: String) async -> Route? {
            routeByKeyCalls.append(key)
            return routesByKey[key]
        }
        func routeMetadata(byKey key: String) async -> RouteReadMetadata? { nil }
        func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? { nil }
        func routeParametersForBackup() async -> [RouteParameters] { [] }
        func routes(containingMarkerID markerID: String) async -> [Route] {
            routesContainingMarkerIDCalls.append(markerID)
            return routesContainingByMarkerID[markerID] ?? []
        }

        func referenceEntity(byID id: String) async -> ReferenceEntity? {
            referenceEntityByIDCalls.append(id)
            return referenceEntitiesByID[id]
        }

        func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? { nil }

        func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? {
            distanceToClosestLocationCallIDs.append(id)
            return distancesByMarkerID[id]
        }

        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? { nil }

        func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? { nil }

        func markerParameters(byID id: String) async -> MarkerParameters? { nil }

        func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? { nil }

        func markerParameters(byEntityKey key: String) async -> MarkerParameters? { nil }

        func markerParametersForBackup() async -> [MarkerParameters] { [] }

        func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? {
            referenceEntityByEntityKeyCalls.append(key)
            return referenceEntitiesByEntityKey[key]
        }

        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? { nil }

        func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? {
            let coordinate = location.location.coordinate
            let key = "\(coordinate.latitude),\(coordinate.longitude)"
            referenceEntityByGenericLocationCalls.append(key)
            return referenceEntitiesByGenericLocation[key]
        }

        func referenceEntities() async -> [ReferenceEntity] { [] }

        func recentlySelectedPOIs() async -> [POI] { [] }

        func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData? { nil }

        func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] { [] }

        func poi(byKey key: String) async -> POI? {
            poiByKeyCalls.append(key)
            return poisByKey[key]
        }

        func road(byKey key: String) async -> Road? { nil }

        func intersections(forRoadKey key: String) async -> [Intersection] { [] }

        func intersection(forRoadKey key: String, at coordinate: SSGeoCoordinate) async -> Intersection? { nil }

        func intersections(forRoadKey key: String, in region: SpatialIntersectionRegion) async -> [Intersection]? { nil }

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<VectorTile> { [] }

        func tileData(for tiles: [VectorTile]) async -> [TileData] { [] }

        func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [POI] { [] }
    }

    final class MockReferenceReadContract: ReferenceReadContract {
        func referenceEntity(byID id: String) async -> ReferenceEntity? { nil }
        func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? { nil }
        func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? { nil }
        func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? { nil }
        func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? { nil }
        func markerParameters(byID id: String) async -> MarkerParameters? { nil }
        func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParameters? { nil }
        func markerParameters(byEntityKey key: String) async -> MarkerParameters? { nil }
        func markerParametersForBackup() async -> [MarkerParameters] { [] }
        func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? { nil }
        func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? { nil }
        func referenceEntity(byGenericLocation location: GenericLocation) async -> ReferenceEntity? { nil }
        func referenceEntities() async -> [ReferenceEntity] { [] }
        func recentlySelectedPOIs() async -> [POI] { [] }
        func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData? { nil }
        func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] { [] }
        func poi(byKey key: String) async -> POI? { nil }
    }

    final class CloudDispatchProbeRuntimeProviders {
        private(set) var referenceUpdateMarkerParametersCalls = 0
        private(set) var referenceRemoveMarkerIDCalls = 0

        func referenceIntegration() -> ReferenceEntityRuntime.Integration {
            .init(
                updateReferenceInCloud: { [self] _ in
                    referenceUpdateMarkerParametersCalls += 1
                },
                removeReferenceFromCloud: { [self] _ in
                    referenceRemoveMarkerIDCalls += 1
                },
                didRemoveReferenceEntity: { _ in },
                setDestinationTemporaryIfMatchingID: { _ in false },
                clearDestinationForCacheReset: {},
                removeCalloutHistoryForMarkerID: { _ in },
                processEvent: { _ in }
            )
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        DataContractRegistry.configureWithRealmDefaults()
    }

    override func tearDownWithError() throws {
        DataContractRegistry.resetForTesting()
        RouteRuntime.resetForTesting()
        ReferenceEntityRuntime.resetForTesting()
        DataRuntimeProviderRegistry.resetForTesting()
        try clearAllRoutes()
    }

    func testObjectKeysDistanceUsesPersistenceWithoutInjectedSpatialStoreFallback() throws {
        let route = try createPersistedRoute(name: "DistanceTestRoute")

        let keys = Route.objectKeys(sortedBy: .distance)

        XCTAssertTrue(keys.contains(route.id))
    }

    func testAsyncObjectKeysDistanceUsesSpatialReadContractDistanceLookup() async throws {
        let markerIDNear = "async-distance-near-\(UUID().uuidString)"
        let markerIDFar = "async-distance-far-\(UUID().uuidString)"
        let nearRoute = try createPersistedRoute(name: "AsyncDistanceNear-\(UUID().uuidString)", markerIDs: [markerIDNear])
        let farRoute = try createPersistedRoute(name: "AsyncDistanceFar-\(UUID().uuidString)", markerIDs: [markerIDFar])

        let readMock = MockSpatialReadContract()
        readMock.routesToReturn = [farRoute, nearRoute]
        readMock.distancesByMarkerID[markerIDNear] = 10
        readMock.distancesByMarkerID[markerIDFar] = 100
        DataContractRegistry.configure(spatialRead: readMock)

        let keys = await Route.asyncObjectKeys(sortedBy: .distance)

        XCTAssertEqual(keys, [nearRoute.id, farRoute.id])
        XCTAssertEqual(readMock.routesCallCount, 1)
        XCTAssertEqual(Set(readMock.distanceToClosestLocationCallIDs), Set([markerIDFar, markerIDNear]))
    }

    func testRemoveWaypointFromAllRoutesUsesSpatialReadContractLookup() async throws {
        let readMock = MockSpatialReadContract()
        readMock.routesContainingByMarkerID["marker-id"] = []

        try await Route.removeWaypointFromAllRoutes(markerId: "marker-id", using: readMock)

        XCTAssertEqual(readMock.routesContainingMarkerIDCalls, ["marker-id"])
    }

    func testRemoveWaypointFromAllRoutesThrowsWhenSpatialRouteReadsAreUnavailable() async {
        let readMock = MockReferenceReadContract()

        do {
            try await Route.removeWaypointFromAllRoutes(markerId: "marker-id", using: readMock)
            XCTFail("Expected invalidReadContract error")
        } catch {
            guard case RouteDataError.invalidReadContract = error else {
                XCTFail("Expected invalidReadContract, received: \(error)")
                return
            }
        }
    }

    func testUpdateWaypointInAllRoutesThrowsWhenSpatialRouteReadsAreUnavailable() async {
        let readMock = MockReferenceReadContract()

        do {
            try await Route.updateWaypointInAllRoutes(markerId: "marker-id", using: readMock)
            XCTFail("Expected invalidReadContract error")
        } catch {
            guard case RouteDataError.invalidReadContract = error else {
                XCTFail("Expected invalidReadContract, received: \(error)")
                return
            }
        }
    }

    func testDeleteAllUsesPersistenceWithoutInjectedSpatialStoreFallback() throws {
        let route = try createPersistedRoute(name: "DeleteAllRoute-\(UUID().uuidString)")

        try Route.deleteAll()

        XCTAssertNil(Route.object(forPrimaryKey: route.id))
    }

    func testDefaultSpatialMaintenanceWriteRemoveAllRoutesUsesSpatialReadContractRoutes() async throws {

        let readMock = MockSpatialReadContract()
        readMock.routesToReturn = []
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialMaintenanceWrite.removeAllRoutes()

        XCTAssertEqual(readMock.routesCallCount, 1)
    }

    func testDefaultSpatialMaintenanceWriteClearNewFlagsUsesPersistenceWithoutStoreFallback() async throws {
        let markerID = "clear-new-marker-\(UUID().uuidString)"
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 42.6205, baseLongitude: -117.3493)
        _ = try createPersistedMarker(id: markerID, coordinate: markerCoordinate)
        let route = try createPersistedRoute(name: "ClearNewRoute-\(UUID().uuidString)", markerIDs: [markerID])

        let database = try RealmHelper.getDatabaseRealm()
        let persistedMarkerBefore = try XCTUnwrap(database.object(ofType: RealmReferenceEntity.self,
                                                                  forPrimaryKey: markerID))
        let persistedRouteBefore = try XCTUnwrap(database.object(ofType: RealmRoute.self,
                                                                 forPrimaryKey: route.id))
        XCTAssertTrue(persistedMarkerBefore.isNew)
        XCTAssertTrue(persistedRouteBefore.isNew)

        try await DataContractRegistry.spatialMaintenanceWrite.clearNewReferenceEntitiesAndRoutes()

        let refreshedDatabase = try RealmHelper.getDatabaseRealm()
        let persistedMarkerAfter = try XCTUnwrap(refreshedDatabase.object(ofType: RealmReferenceEntity.self,
                                                                          forPrimaryKey: markerID))
        let persistedRouteAfter = try XCTUnwrap(refreshedDatabase.object(ofType: RealmRoute.self,
                                                                         forPrimaryKey: route.id))
        XCTAssertFalse(persistedMarkerAfter.isNew)
        XCTAssertFalse(persistedRouteAfter.isNew)
    }

    func testEncodeFromDetailUsesSpatialReadContractRouteLookup() async throws {
        let route = try createPersistedRoute(name: "EncodeRoute")
        let readMock = MockSpatialReadContract()
        readMock.routesByKey[route.id] = route
        DataContractRegistry.configure(spatialRead: readMock)

        let detail = RouteDetail(source: .database(id: route.id))
        let data = await RouteParameters.encode(from: detail, context: .backup)

        XCTAssertNotNil(data)
        XCTAssertEqual(readMock.routeByKeyCalls, [route.id])
    }

    func testRouteInitFromParametersUsesPersistenceMarkerLookupWithoutInjectedStoreFallback() throws {
        let markerID = "init-from-parameters-marker-\(UUID().uuidString)"
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        _ = try createPersistedMarker(id: markerID, coordinate: markerCoordinate)

        let parameters = RouteParameters(id: "init-from-parameters-route-\(UUID().uuidString)",
                                         name: "InitFromParametersRoute",
                                         routeDescription: nil,
                                         waypoints: [RouteWaypointParameters(index: 0, markerId: markerID, marker: nil)],
                                         createdDate: nil,
                                         lastUpdatedDate: nil,
                                         lastSelectedDate: nil)

        let route = Route(from: parameters)

        XCTAssertEqual(route.firstWaypointLatitude ?? 0, markerCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(route.firstWaypointLongitude ?? 0, markerCoordinate.longitude, accuracy: 0.000_001)
    }

    func testRouteInitFromParametersUsesProvidedFirstWaypointCoordinateWithoutStoreLookup() {
        let markerID = "explicit-first-waypoint-\(UUID().uuidString)"
        let explicitCoordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let parameters = RouteParameters(id: "explicit-route-\(UUID().uuidString)",
                                         name: "Explicit First Waypoint",
                                         routeDescription: nil,
                                         waypoints: [RouteWaypointParameters(index: 0, markerId: markerID, marker: nil)],
                                         createdDate: nil,
                                         lastUpdatedDate: nil,
                                         lastSelectedDate: nil)

        let route = Route(from: parameters, firstWaypointCoordinate: explicitCoordinate)

        XCTAssertEqual(route.firstWaypointLatitude ?? 0, explicitCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(route.firstWaypointLongitude ?? 0, explicitCoordinate.longitude, accuracy: 0.000_001)
    }

    func testRouteInitFromParametersHydratesFirstWaypointCoordinatesFromMarker() throws {
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        let markerID = "hydration-marker-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: markerID, coordinate: markerCoordinate)

        let parameters = RouteParameters(id: "hydration-route-\(UUID().uuidString)",
                                         name: "Hydration Route",
                                         routeDescription: nil,
                                         waypoints: [RouteWaypointParameters(index: 0, markerId: markerID, marker: nil)],
                                         createdDate: nil,
                                         lastUpdatedDate: nil,
                                         lastSelectedDate: nil)

        let route = Route(from: parameters)

        let firstLatitude = try XCTUnwrap(route.firstWaypointLatitude)
        let firstLongitude = try XCTUnwrap(route.firstWaypointLongitude)
        XCTAssertEqual(firstLatitude, markerCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(firstLongitude, markerCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(route.waypoints.ordered.first?.markerId, markerID)
    }

    func testRouteParametersHandlerHydratesMissingFirstWaypointCoordinateViaAsyncReadContract() {
        let markerID = "handler-marker-\(UUID().uuidString)"
        let storeCoordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let asyncReadCoordinate = CLLocationCoordinate2D(latitude: 48.1122, longitude: -122.7711)
        let marker = RealmReferenceEntity(coordinate: storeCoordinate)
        marker.id = markerID

        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[markerID] = ReferenceEntity(id: markerID,
                                                                   entityKey: nil,
                                                                   lastUpdatedDate: nil,
                                                                   lastSelectedDate: nil,
                                                                   isNew: false,
                                                                   isTemp: false,
                                                                   coordinate: asyncReadCoordinate.ssGeoCoordinate,
                                                                   nickname: nil,
                                                                   estimatedAddress: nil,
                                                                   annotation: nil)
        DataContractRegistry.configure(spatialRead: readMock)

        let parameters = RouteParameters(id: "handler-route-\(UUID().uuidString)",
                                         name: "Handler Route",
                                         routeDescription: nil,
                                         waypoints: [RouteWaypointParameters(index: 0, markerId: markerID, marker: nil)],
                                         createdDate: nil,
                                         lastUpdatedDate: nil,
                                         lastSelectedDate: nil)

        let handler = RouteParametersHandler()
        let expectation = expectation(description: "hydrate first waypoint via async read contract")

        handler.makeRoute(from: parameters) { result in
            switch result {
            case .success(let route):
                XCTAssertEqual(route.firstWaypointLatitude ?? 0, asyncReadCoordinate.latitude, accuracy: 0.000_001)
                XCTAssertEqual(route.firstWaypointLongitude ?? 0, asyncReadCoordinate.longitude, accuracy: 0.000_001)
            case .failure(let error):
                XCTFail("Expected route initialization to succeed, received error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(markerID))
    }

    func testRouteParametersHandlerPrefersWaypointPayloadCoordinateOverAsyncReadContract() {
        let markerID = "handler-payload-marker-\(UUID().uuidString)"
        let payloadCoordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let asyncReadCoordinate = CLLocationCoordinate2D(latitude: 48.1122, longitude: -122.7711)

        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[markerID] = ReferenceEntity(id: markerID,
                                                                   entityKey: nil,
                                                                   lastUpdatedDate: nil,
                                                                   lastSelectedDate: nil,
                                                                   isNew: false,
                                                                   isTemp: false,
                                                                   coordinate: asyncReadCoordinate.ssGeoCoordinate,
                                                                   nickname: nil,
                                                                   estimatedAddress: nil,
                                                                   annotation: nil)
        DataContractRegistry.configure(spatialRead: readMock)

        let parameters = RouteParameters(id: "handler-route-\(UUID().uuidString)",
                                         name: "Handler Route Payload First",
                                         routeDescription: nil,
                                         waypoints: [RouteWaypointParameters(index: 0,
                                                                             markerId: markerID,
                                                                             marker: MarkerParameters(name: "Payload Marker",
                                                                                                      latitude: payloadCoordinate.latitude,
                                                                                                      longitude: payloadCoordinate.longitude))],
                                         createdDate: nil,
                                         lastUpdatedDate: nil,
                                         lastSelectedDate: nil)

        let handler = RouteParametersHandler()
        let expectation = expectation(description: "hydrate first waypoint from payload")

        handler.makeRoute(from: parameters) { result in
            switch result {
            case .success(let route):
                XCTAssertEqual(route.firstWaypointLatitude ?? 0, payloadCoordinate.latitude, accuracy: 0.000_001)
                XCTAssertEqual(route.firstWaypointLongitude ?? 0, payloadCoordinate.longitude, accuracy: 0.000_001)
            case .failure(let error):
                XCTFail("Expected route initialization to succeed, received error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(readMock.referenceEntityByIDCalls.contains(markerID))
    }

    func testRouteWaypointLocationDetailUsesAsyncReadContractWithoutSyncFallback() async {
        let markerID = "waypoint-async-marker-\(UUID().uuidString)"
        let storeMarkerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        let storeMarker = RealmReferenceEntity(coordinate: storeMarkerCoordinate, entityKey: nil, name: "Store Marker")
        storeMarker.id = markerID

        let readMock = MockSpatialReadContract()
        let waypoint = RouteWaypoint(index: 0, markerId: markerID)

        let detail = await waypoint.locationDetail(using: readMock)

        XCTAssertNil(detail)
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [markerID])
    }

    func testRouteDetailCacheSourceHydratesWaypointsUsingSpatialReadContract() async {
        let markerID = "route-detail-marker-\(UUID().uuidString)"
        let coordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[markerID] = ReferenceEntity(id: markerID,
                                                                   entityKey: nil,
                                                                   lastUpdatedDate: nil,
                                                                   lastSelectedDate: nil,
                                                                   isNew: false,
                                                                   isTemp: false,
                                                                   coordinate: coordinate.ssGeoCoordinate,
                                                                   nickname: "Route Detail Marker",
                                                                   estimatedAddress: nil,
                                                                   annotation: nil)
        DataContractRegistry.configure(spatialRead: readMock)

        let route = Route(name: "Hydrated Route",
                          description: "A route description",
                          waypoints: [RouteWaypoint(index: 0, markerId: markerID)])
        let detail = RouteDetail(source: .cache(route: route))

        for _ in 0..<10 where detail.waypoints.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(detail.displayName, "Hydrated Route")
        XCTAssertEqual(detail.waypoints.count, 1)
        XCTAssertEqual(detail.waypoints.first?.markerId, markerID)
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [markerID])
    }

    func testMarkerParametersInitMarkerIDUsesContractLookup() async throws {
        let markerID = "marker-id-\(UUID().uuidString)"
        let coordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        _ = try createPersistedMarker(id: markerID, coordinate: coordinate)

        let parameters = await MarkerParameters(markerId: markerID)

        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?.id, markerID)
    }

    func testMarkerParametersInitGenericLocationUsesContractLookup() async throws {
        let genericLocation = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Generic")
        let expectedCoordinate = genericLocation.location.coordinate
        _ = try createPersistedMarker(id: "marker-generic-\(UUID().uuidString)", coordinate: expectedCoordinate)

        let parameters = await MarkerParameters(entity: genericLocation)

        XCTAssertNotNil(parameters)
    }

    func testLocationDetailLoadEntityIDUsesContractLookup() async {
        let entityKey = "location-detail-entity-\(UUID().uuidString)"
        let readMock = MockSpatialReadContract()
        let poi = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Contract POI")
        poi.key = entityKey
        readMock.poisByKey[entityKey] = poi
        DataContractRegistry.configure(spatialRead: readMock)

        let detail = await LocationDetail.load(entityId: entityKey)

        XCTAssertNotNil(detail)
        XCTAssertEqual(detail?.entity?.key, entityKey)
        XCTAssertEqual(readMock.poiByKeyCalls, [entityKey])
    }

    func testLocationDetailLoadEntityResolvesGenericLocationMarkerThroughContract() async {
        let coordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        let readMock = MockSpatialReadContract()
        let entity = GenericLocation(lat: coordinate.latitude, lon: coordinate.longitude, name: "Generic Location")
        let entityCoordinate = entity.location.coordinate
        let key = "\(entityCoordinate.latitude),\(entityCoordinate.longitude)"
        let markerID = "generic-location-marker-\(UUID().uuidString)"
        readMock.referenceEntitiesByGenericLocation[key] = ReferenceEntity(id: markerID,
                                                                           entityKey: nil,
                                                                           lastUpdatedDate: nil,
                                                                           lastSelectedDate: nil,
                                                                           isNew: false,
                                                                           isTemp: false,
                                                                           coordinate: entityCoordinate.ssGeoCoordinate,
                                                                           nickname: "Stored Marker",
                                                                           estimatedAddress: nil,
                                                                           annotation: nil)
        DataContractRegistry.configure(spatialRead: readMock)

        let detail = await LocationDetail.load(entity: entity, telemetryContext: "unit_test")

        XCTAssertEqual(detail.markerId, markerID)
        XCTAssertEqual(readMock.referenceEntityByGenericLocationCalls, [key])
    }

    func testSpatialDataCacheSearchByKeyWithNoProvidersReturnsNilWithoutAssert() {
        SpatialDataCache.removeAllProviders()
        defer {
            SpatialDataCache.removeAllProviders()
            SpatialDataCache.register(provider: OSMPOISearchProvider())
            SpatialDataCache.register(provider: AddressSearchProvider())
            SpatialDataCache.register(provider: GenericLocationSearchProvider())
        }

        let poi = SpatialDataCache.searchByKey(key: "default-store-search-\(UUID().uuidString)")

        XCTAssertNil(poi)
    }

    func testLocationDetailStoreAdapterPOIWithNoProvidersReturnsNilWithoutInjectedStoreFallback() {
        SpatialDataCache.removeAllProviders()
        defer {
            SpatialDataCache.removeAllProviders()
            SpatialDataCache.register(provider: OSMPOISearchProvider())
            SpatialDataCache.register(provider: AddressSearchProvider())
            SpatialDataCache.register(provider: GenericLocationSearchProvider())
        }

        let key = "location-detail-poi-\(UUID().uuidString)"
        let storeOnlyPOI = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Store-only POI")
        storeOnlyPOI.key = key

        let poi = LocationDetailStoreAdapter.poi(byKey: key)

        XCTAssertNil(poi)
    }

    func testReverseGeocoderLookupPOIWithNoProvidersReturnsNil() {
        SpatialDataCache.removeAllProviders()
        defer {
            SpatialDataCache.removeAllProviders()
            SpatialDataCache.register(provider: OSMPOISearchProvider())
            SpatialDataCache.register(provider: AddressSearchProvider())
            SpatialDataCache.register(provider: GenericLocationSearchProvider())
        }

        let key = "reverse-geocoder-poi-\(UUID().uuidString)"

        let poi = ReverseGeocoderLookup.poi(by: key)

        XCTAssertNil(poi)
    }

    func testReverseGeocoderLookupRoadWithNoProvidersReturnsNilWithoutAssert() {
        SpatialDataCache.removeAllProviders()
        defer {
            SpatialDataCache.removeAllProviders()
            SpatialDataCache.register(provider: OSMPOISearchProvider())
            SpatialDataCache.register(provider: AddressSearchProvider())
            SpatialDataCache.register(provider: GenericLocationSearchProvider())
        }

        let key = "reverse-geocoder-road-\(UUID().uuidString)"

        let road = ReverseGeocoderLookup.road(by: key)

        XCTAssertNil(road)
    }

    func testReferenceEntityGetPOIUsesPersistenceSearchWithoutInjectedStoreFallback() {
        let key = "poi-key-\(UUID().uuidString)"

        let reference = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493),
                                        entityKey: key)
        let poi = reference.getPOI()

        XCTAssertTrue(poi is GenericLocation)
    }

    func testSpatialDataResultEntityEntrancesUsePersistenceLookupWithoutInjectedStoreFallback() {
        let entity = GDASpatialDataResultEntity()
        entity.coordinatesJson = "{\"type\":\"LineString\",\"coordinates\":[[-122.35,47.62],[-122.34,47.63]]}"
        entity.entrancesJson = "[\"entrance-1\"]"
        let storeOnlyPOI = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Store-only entrance")
        storeOnlyPOI.key = "entrance-1"

        XCTAssertNotNil(entity.coordinates)
        let entrances = entity.entrances

        XCTAssertEqual(entrances?.count, 0)
    }


    func testDefaultSpatialReadRouteByKeyUsesPersistenceWithoutInjectedStoreFallback() async throws {
        let route = try createPersistedRoute(name: "DefaultSpatialReadRouteByKey-\(UUID().uuidString)")
        DataContractRegistry.resetForTesting()

        let fetchedRoute = await DataContractRegistry.spatialRead.route(byKey: route.id)

        XCTAssertEqual(fetchedRoute?.id, route.id)
    }

    func testDefaultSpatialReadRouteParametersForBackupUsesPersistenceWithoutInjectedStoreFallback() async throws {
        let route = try createPersistedRoute(name: "DefaultSpatialReadRouteParameters-\(UUID().uuidString)")
        DataContractRegistry.resetForTesting()

        let routeParameters = await DataContractRegistry.spatialRead.routeParametersForBackup()

        XCTAssertTrue(routeParameters.contains(where: { $0.id == route.id }))
    }

    func testDefaultSpatialReadReferenceEntityByIDUsesPersistenceWithoutInjectedStoreFallback() async throws {
        let markerID = "default-spatial-read-marker-\(UUID().uuidString)"
        let coordinate = makeUniqueCoordinate(baseLatitude: 41.6205, baseLongitude: -116.3493)
        _ = try createPersistedMarker(id: markerID, coordinate: coordinate)
        DataContractRegistry.resetForTesting()

        let referenceEntity = await DataContractRegistry.spatialRead.referenceEntity(byID: markerID)

        XCTAssertEqual(referenceEntity?.id, markerID)
    }

    func testDefaultSpatialReadReferenceEntitiesNearUsesPersistenceWithoutInjectedStoreFallback() async throws {
        let markerID = "default-spatial-read-near-\(UUID().uuidString)"
        let coordinate = makeUniqueCoordinate(baseLatitude: 41.7205, baseLongitude: -116.4493)
        _ = try createPersistedMarker(id: markerID, coordinate: coordinate)
        let lookupKey = "\(coordinate.latitude),\(coordinate.longitude)@\(50.0)"
        DataContractRegistry.resetForTesting()

        let entities = await DataContractRegistry.spatialRead.referenceEntities(near: coordinate.ssGeoCoordinate,
                                                                                rangeMeters: 50.0)

        XCTAssertTrue(entities.contains(where: { $0.id == markerID }))
    }

    func testReferenceEntityAddEntityKeyUsesSpatialReadContractForExistenceAndPOILookup() async {
        let missingKey = "missing-entity-key"
        let spatialRead = MockSpatialReadContract()

        do {
            _ = try await RealmReferenceEntity.add(entityKey: missingKey,
                                                   nickname: nil,
                                                   estimatedAddress: nil,
                                                   annotation: nil,
                                                   temporary: false,
                                                   context: nil,
                                                   notify: false,
                                                   using: spatialRead)
            XCTFail("Expected entityDoesNotExist error")
        } catch {
            guard case ReferenceEntityError.entityDoesNotExist = error else {
                XCTFail("Expected entityDoesNotExist, received: \(error)")
                return
            }
        }

        XCTAssertEqual(spatialRead.referenceEntityByEntityKeyCalls, [missingKey])
        XCTAssertEqual(spatialRead.poiByKeyCalls, [missingKey])
    }

    func testDefaultSpatialWriteAddReferenceEntityEntityKeyUsesMarkerParametersCloudDispatchWithoutStoreFallback() async throws {
        let entityKey = "add-write-entity-key-\(UUID().uuidString)"
        let coordinate = makeUniqueCoordinate(baseLatitude: 40.6205, baseLongitude: -115.3493)
        let storeOnlyPOI = GenericLocation(lat: coordinate.latitude,
                                           lon: coordinate.longitude,
                                           name: "Store-Only Name")
        storeOnlyPOI.key = entityKey

        let readMock = MockSpatialReadContract()
        let contractPOI = GenericLocation(lat: coordinate.latitude,
                                          lon: coordinate.longitude,
                                          name: "Contract POI Name")
        contractPOI.key = entityKey
        readMock.poisByKey[entityKey] = contractPOI
        DataContractRegistry.configure(spatialRead: readMock)

        let runtimeProviders = CloudDispatchProbeRuntimeProviders()
        ReferenceEntityRuntime.configure(with: runtimeProviders.referenceIntegration())

        let markerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: entityKey,
                                                                                       nickname: "Cloud Name",
                                                                                       estimatedAddress: "Address",
                                                                                       annotation: "Annotation")

        let database = try RealmHelper.getDatabaseRealm()
        let marker = try XCTUnwrap(database.object(ofType: RealmReferenceEntity.self, forPrimaryKey: markerID))
        XCTAssertEqual(marker.entityKey, entityKey)
        XCTAssertEqual(marker.nickname, "Cloud Name")

        XCTAssertEqual(readMock.referenceEntityByEntityKeyCalls, [entityKey])
        XCTAssertEqual(readMock.poiByKeyCalls, [entityKey])
        XCTAssertEqual(runtimeProviders.referenceUpdateMarkerParametersCalls, 1)
    }

    func testDefaultSpatialWriteAddReferenceEntityLocationUsesMarkerParametersCloudDispatchWithoutStoreFallback() async throws {
        let coordinate = makeUniqueCoordinate(baseLatitude: 40.7105, baseLongitude: -115.2793)
        let location = GenericLocation(lat: coordinate.latitude,
                                       lon: coordinate.longitude,
                                       name: "Contract Location Name")
        let coordinateKey = "\(coordinate.latitude),\(coordinate.longitude)"

        let readMock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: readMock)

        let runtimeProviders = CloudDispatchProbeRuntimeProviders()
        ReferenceEntityRuntime.configure(with: runtimeProviders.referenceIntegration())

        let markerID = try await DataContractRegistry.spatialWrite.addReferenceEntity(location: location,
                                                                                       nickname: "Cloud Location",
                                                                                       estimatedAddress: "Address",
                                                                                       annotation: "Annotation")

        let database = try RealmHelper.getDatabaseRealm()
        let marker = try XCTUnwrap(database.object(ofType: RealmReferenceEntity.self, forPrimaryKey: markerID))
        XCTAssertEqual(marker.nickname, "Cloud Location")
        XCTAssertEqual(marker.estimatedAddress, "Address")
        XCTAssertEqual(marker.annotation, "Annotation")
        XCTAssertEqual(readMock.referenceEntityByGenericLocationCalls, [coordinateKey])
        XCTAssertEqual(runtimeProviders.referenceUpdateMarkerParametersCalls, 1)
    }

    func testReferenceEntityAddLocationUsesSpatialReadContractGenericLocationLookup() async throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Lookup")
        let existingMarkerID = "existing-location-marker-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: existingMarkerID, coordinate: location.location.coordinate)
        let key = "\(location.location.coordinate.latitude),\(location.location.coordinate.longitude)"
        let spatialRead = MockSpatialReadContract()
        spatialRead.referenceEntitiesByGenericLocation[key] = ReferenceEntity(id: existingMarkerID,
                                                                              entityKey: nil,
                                                                              lastUpdatedDate: nil,
                                                                              lastSelectedDate: nil,
                                                                              isNew: false,
                                                                              isTemp: false,
                                                                              coordinate: location.location.coordinate.ssGeoCoordinate,
                                                                              nickname: nil,
                                                                              estimatedAddress: nil,
                                                                              annotation: nil)

        let id = try await RealmReferenceEntity.add(location: location,
                                                    nickname: nil,
                                                    estimatedAddress: nil,
                                                    annotation: nil,
                                                    temporary: true,
                                                    context: "test",
                                                    notify: false,
                                                    using: spatialRead)

        XCTAssertEqual(id, existingMarkerID)
        XCTAssertEqual(spatialRead.referenceEntityByGenericLocationCalls, [key])
    }

    func testLocationParametersFetchEntityUsesSpatialReadContractPOILookup() {
        let lookupID = "osm-lookup-id"
        let locationParameters = LocationParameters(name: "Test Entity",
                                                    address: nil,
                                                    coordinate: CoordinateParameters(latitude: 47.6205, longitude: -122.3493),
                                                    entity: EntityParameters(source: .osm, lookupInformation: lookupID))
        let cachedEntity = GDASpatialDataResultEntity(id: lookupID, parameters: locationParameters)

        let readMock = MockSpatialReadContract()
        readMock.poisByKey[lookupID] = cachedEntity
        DataContractRegistry.configure(spatialRead: readMock)

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
        XCTAssertEqual(readMock.poiByKeyCalls, [lookupID])
    }

    func testRouteAddAsyncUsesSpatialReadContractLocationLookup() async throws {
        let waypointLocation = CLLocation(latitude: 47.6205, longitude: -122.3493)
        let imported = ImportedLocationDetail(nickname: "Waypoint", annotation: "Test waypoint")
        let waypointDetail = LocationDetail(location: waypointLocation, imported: imported, telemetryContext: nil)
        let waypoint = RouteWaypoint(index: 0,
                                     markerId: "initial-marker-id",
                                     importedLocationDetail: waypointDetail)
        let route = Route(name: "RouteAddInjectedStore-\(UUID().uuidString)", description: nil, waypoints: [waypoint])

        let existingMarkerID = "existing-route-add-marker-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: existingMarkerID, coordinate: waypointLocation.coordinate)
        let existingMarker = ReferenceEntity(id: existingMarkerID,
                                             entityKey: nil,
                                             lastUpdatedDate: nil,
                                             lastSelectedDate: nil,
                                             isNew: false,
                                             isTemp: false,
                                             coordinate: waypointLocation.coordinate.ssGeoCoordinate,
                                             nickname: nil,
                                             estimatedAddress: nil,
                                             annotation: nil)
        let locationKey = "\(waypointLocation.coordinate.latitude),\(waypointLocation.coordinate.longitude)"
        let spatialRead = MockSpatialReadContract()
        spatialRead.referenceEntitiesByGenericLocation[locationKey] = existingMarker
        spatialRead.referenceEntitiesByID[existingMarkerID] = existingMarker

        try await Route.add(route, using: spatialRead)

        let persistedRoute = Route.object(forPrimaryKey: route.id)
        XCTAssertEqual(spatialRead.referenceEntityByGenericLocationCalls, [locationKey])
        XCTAssertTrue(spatialRead.referenceEntityByIDCalls.contains(existingMarkerID))
        XCTAssertEqual(persistedRoute?.waypoints.ordered.first?.markerId, existingMarkerID)
    }

    func testRouteAddAsyncUpdatesExistingMarkerByAsyncReadContractWhenInjectedStoreLookupIsEmpty() async throws {
        let existingMarkerID = "route-add-existing-\(UUID().uuidString)"
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        _ = try createPersistedMarker(id: existingMarkerID, coordinate: markerCoordinate)

        let waypoint = RouteWaypoint(index: 0, markerId: existingMarkerID)
        let route = Route(name: "RouteAddContractMarker-\(UUID().uuidString)",
                          description: nil,
                          waypoints: [waypoint])

        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[existingMarkerID] = ReferenceEntity(id: existingMarkerID,
                                                                           entityKey: nil,
                                                                           lastUpdatedDate: nil,
                                                                           lastSelectedDate: nil,
                                                                           isNew: false,
                                                                           isTemp: false,
                                                                           coordinate: markerCoordinate.ssGeoCoordinate,
                                                                           nickname: nil,
                                                                           estimatedAddress: nil,
                                                                           annotation: nil)

        try await Route.add(route, using: readMock)

        let persistedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(persistedRoute.waypoints.ordered.first?.markerId, existingMarkerID)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(existingMarkerID))
    }

    func testRouteUpdatePersistsFirstWaypointCoordinatesFromUpdatedWaypointOrder() throws {
        let firstMarkerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        let secondMarkerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6301, baseLongitude: -122.3402)
        let firstMarkerID = "update-first-\(UUID().uuidString)"
        let secondMarkerID = "update-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: firstMarkerID, coordinate: firstMarkerCoordinate)
        _ = try createPersistedMarker(id: secondMarkerID, coordinate: secondMarkerCoordinate)

        let route = try createPersistedRoute(name: "FirstWaypointUpdate-\(UUID().uuidString)", markerIDs: [firstMarkerID, secondMarkerID])

        let reorderedFirst = RouteWaypoint(index: 0, markerId: secondMarkerID)
        let reorderedSecond = RouteWaypoint(index: 1, markerId: firstMarkerID)

        try Route.update(id: route.id,
                         name: route.name,
                         description: route.routeDescription,
                         waypoints: [reorderedFirst, reorderedSecond])

        guard let updatedRoute = Route.object(forPrimaryKey: route.id) else {
            XCTFail("Expected updated route to be persisted")
            return
        }

        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, secondMarkerID)
        let updatedLatitude = try XCTUnwrap(updatedRoute.firstWaypointLatitude)
        let updatedLongitude = try XCTUnwrap(updatedRoute.firstWaypointLongitude)
        XCTAssertEqual(updatedLatitude, secondMarkerCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedLongitude, secondMarkerCoordinate.longitude, accuracy: 0.000_001)
    }

    func testCreateReversedRoutePersistsBidirectionalReverseLink() async throws {
        let firstMarkerID = "reverse-first-\(UUID().uuidString)"
        let secondMarkerID = "reverse-second-\(UUID().uuidString)"
        let firstCoordinate = makeUniqueCoordinate(baseLatitude: 46.6205, baseLongitude: -121.3493)
        let secondCoordinate = makeUniqueCoordinate(baseLatitude: 46.6301, baseLongitude: -121.3402)
        _ = try createPersistedMarker(id: firstMarkerID,
                                      coordinate: firstCoordinate)
        _ = try createPersistedMarker(id: secondMarkerID,
                                      coordinate: secondCoordinate)
        let route = try createPersistedRoute(name: "ReverseLink-\(UUID().uuidString)", markerIDs: [firstMarkerID, secondMarkerID])

        guard let reversedRoute = try await Route.createReversedRoute(from: route, using: DataContractRegistry.spatialRead),
              let persistedRoute = Route.object(forPrimaryKey: route.id) else {
            XCTFail("Expected reversed route and persisted original route")
            return
        }

        XCTAssertNotEqual(reversedRoute.id, persistedRoute.id)
        XCTAssertEqual(persistedRoute.reversedRouteId, reversedRoute.id)
        XCTAssertEqual(reversedRoute.reversedRouteId, persistedRoute.id)
    }

    func testCreateReversedRouteResolvesNameConflictWithNumericSuffix() async throws {
        let originalFirstMarkerID = "reverse-conflict-original-first-\(UUID().uuidString)"
        let originalSecondMarkerID = "reverse-conflict-original-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: originalFirstMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 45.6205, baseLongitude: -120.3493))
        _ = try createPersistedMarker(id: originalSecondMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 45.6301, baseLongitude: -120.3402))
        let route = try createPersistedRoute(name: "ReverseConflict-\(UUID().uuidString)",
                                             markerIDs: [originalFirstMarkerID, originalSecondMarkerID])

        let reversedBaseName = GDLocalizedString("routes.reverse_name_format", route.name)
        let conflictFirstMarkerID = "reverse-conflict-existing-first-\(UUID().uuidString)"
        let conflictSecondMarkerID = "reverse-conflict-existing-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: conflictFirstMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 45.6405, baseLongitude: -120.3293))
        _ = try createPersistedMarker(id: conflictSecondMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 45.6501, baseLongitude: -120.3202))
        let conflictingRoute = try createPersistedRoute(name: reversedBaseName,
                                                        markerIDs: [conflictFirstMarkerID, conflictSecondMarkerID])

        guard let reversedRoute = try await Route.createReversedRoute(from: route, using: DataContractRegistry.spatialRead),
              let persistedRoute = Route.object(forPrimaryKey: route.id),
              let persistedConflictingRoute = Route.object(forPrimaryKey: conflictingRoute.id) else {
            XCTFail("Expected reversed route and persisted original route")
            return
        }

        XCTAssertEqual(reversedRoute.name, "\(reversedBaseName) (2)")
        XCTAssertEqual(persistedRoute.reversedRouteId, reversedRoute.id)
        XCTAssertEqual(reversedRoute.reversedRouteId, persistedRoute.id)
        XCTAssertNil(persistedConflictingRoute.reversedRouteId)
    }

    func testCreateReversedRouteAsyncHydratesFirstWaypointFromReadContract() async throws {
        try await DataContractRegistry.spatialMaintenanceWrite.removeAllReferenceEntities()

        let firstMarkerID = "reverse-async-first-\(UUID().uuidString)"
        let secondMarkerID = "reverse-async-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: firstMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 44.6205, baseLongitude: -119.3493))
        _ = try createPersistedMarker(id: secondMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 44.6301, baseLongitude: -119.3402))
        let route = try createPersistedRoute(name: "ReverseAsync-\(UUID().uuidString)",
                                             markerIDs: [firstMarkerID, secondMarkerID])

        let asyncCoordinate = CLLocationCoordinate2D(latitude: 49.1234, longitude: -123.4567)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[secondMarkerID] = ReferenceEntity(id: secondMarkerID,
                                                                         entityKey: nil,
                                                                         lastUpdatedDate: nil,
                                                                         lastSelectedDate: nil,
                                                                         isNew: false,
                                                                         isTemp: false,
                                                                         coordinate: asyncCoordinate.ssGeoCoordinate,
                                                                         nickname: nil,
                                                                         estimatedAddress: nil,
                                                                         annotation: nil)

        let reversedRoute = try await Route.createReversedRoute(from: route, using: readMock)

        let persistedReversedRoute = try XCTUnwrap(reversedRoute)
        XCTAssertEqual(persistedReversedRoute.waypoints.ordered.first?.markerId, secondMarkerID)
        XCTAssertEqual(persistedReversedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(persistedReversedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(secondMarkerID))
    }

    func testDefaultSpatialWriteRemoveReferenceEntityHydratesRemainingRouteWaypointFromAsyncReadContract() async throws {
        let removedMarkerID = "remove-write-first-\(UUID().uuidString)"
        let remainingMarkerID = "remove-write-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: removedMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 43.6205, baseLongitude: -118.3493))
        _ = try createPersistedMarker(id: remainingMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 43.6301, baseLongitude: -118.3402))
        let route = try createPersistedRoute(name: "RemoveWriteAsync-\(UUID().uuidString)",
                                             markerIDs: [removedMarkerID, remainingMarkerID])

        let asyncCoordinate = CLLocationCoordinate2D(latitude: 50.1234, longitude: -124.4567)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[remainingMarkerID] = ReferenceEntity(id: remainingMarkerID,
                                                                            entityKey: nil,
                                                                            lastUpdatedDate: nil,
                                                                            lastSelectedDate: nil,
                                                                            isNew: false,
                                                                            isTemp: false,
                                                                            coordinate: asyncCoordinate.ssGeoCoordinate,
                                                                            nickname: nil,
                                                                            estimatedAddress: nil,
                                                                            annotation: nil)
        readMock.routesContainingByMarkerID[removedMarkerID] = [route]
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialWrite.removeReferenceEntity(id: removedMarkerID)

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, remainingMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(remainingMarkerID))
        XCTAssertEqual(readMock.routesContainingMarkerIDCalls, [removedMarkerID])
    }

    func testDefaultSpatialWriteRemoveReferenceEntityUsesMarkerIDCloudDispatchWithoutStorePOIFallback() async throws {
        let removedMarkerID = "remove-write-cloud-dispatch-first-\(UUID().uuidString)"
        let remainingMarkerID = "remove-write-cloud-dispatch-second-\(UUID().uuidString)"
        let removedEntityKey = "remove-write-cloud-dispatch-entity-key-\(UUID().uuidString)"

        let removedMarker = RealmReferenceEntity(coordinate: makeUniqueCoordinate(baseLatitude: 46.6205,
                                                                                   baseLongitude: -121.3493),
                                                 entityKey: removedEntityKey,
                                                 name: nil)
        removedMarker.id = removedMarkerID
        removedMarker.isTemp = false

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(removedMarker, update: .modified)
        }

        _ = try createPersistedMarker(id: remainingMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 46.6301, baseLongitude: -121.3402))
        let route = try createPersistedRoute(name: "RemoveWriteCloudDispatch-\(UUID().uuidString)",
                                             markerIDs: [removedMarkerID, remainingMarkerID])

        let asyncCoordinate = CLLocationCoordinate2D(latitude: 52.1234, longitude: -126.4567)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[remainingMarkerID] = ReferenceEntity(id: remainingMarkerID,
                                                                            entityKey: nil,
                                                                            lastUpdatedDate: nil,
                                                                            lastSelectedDate: nil,
                                                                            isNew: false,
                                                                            isTemp: false,
                                                                            coordinate: asyncCoordinate.ssGeoCoordinate,
                                                                            nickname: nil,
                                                                            estimatedAddress: nil,
                                                                            annotation: nil)
        readMock.routesContainingByMarkerID[removedMarkerID] = [route]
        DataContractRegistry.configure(spatialRead: readMock)
        let storeOnlyPOI = GenericLocation(lat: 46.6205,
                                           lon: -121.3493,
                                           name: "Store-Only Removed POI")
        storeOnlyPOI.key = removedEntityKey

        let runtimeProviders = CloudDispatchProbeRuntimeProviders()
        ReferenceEntityRuntime.configure(with: runtimeProviders.referenceIntegration())

        try await DataContractRegistry.spatialWrite.removeReferenceEntity(id: removedMarkerID)

        XCTAssertEqual(runtimeProviders.referenceRemoveMarkerIDCalls, 1)
    }

    func testDefaultSpatialWriteUpdateReferenceEntityHydratesFirstWaypointFromAsyncReadContract() async throws {
        let firstMarkerID = "update-write-first-\(UUID().uuidString)"
        let secondMarkerID = "update-write-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: firstMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 42.6205, baseLongitude: -117.3493))
        _ = try createPersistedMarker(id: secondMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 42.6301, baseLongitude: -117.3402))
        let route = try createPersistedRoute(name: "UpdateWriteAsync-\(UUID().uuidString)",
                                             markerIDs: [firstMarkerID, secondMarkerID])

        let asyncCoordinate = CLLocationCoordinate2D(latitude: 51.1234, longitude: -125.4567)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[firstMarkerID] = ReferenceEntity(id: firstMarkerID,
                                                                        entityKey: nil,
                                                                        lastUpdatedDate: nil,
                                                                        lastSelectedDate: nil,
                                                                        isNew: false,
                                                                        isTemp: false,
                                                                        coordinate: asyncCoordinate.ssGeoCoordinate,
                                                                        nickname: nil,
                                                                        estimatedAddress: nil,
                                                                        annotation: nil)
        readMock.routesContainingByMarkerID[firstMarkerID] = [route]
        DataContractRegistry.configure(spatialRead: readMock)

        let updatedMarkerCoordinate = SSGeoCoordinate(latitude: 41.1111, longitude: -116.2222)
        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: firstMarkerID,
                                                                          location: updatedMarkerCoordinate,
                                                                          nickname: "Updated Marker",
                                                                          estimatedAddress: nil,
                                                                          annotation: nil)

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, firstMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(firstMarkerID))
        XCTAssertEqual(readMock.routesContainingMarkerIDCalls, [firstMarkerID])
    }

    func testDefaultSpatialWriteUpdateReferenceEntityLocationChangeUsesSpatialReadPOILookupWithoutStoreFallback() async throws {
        let markerID = "update-write-location-change-\(UUID().uuidString)"
        let entityKey = "update-write-entity-key-\(UUID().uuidString)"
        let originalCoordinate = makeUniqueCoordinate(baseLatitude: 43.6205, baseLongitude: -118.3493)
        let updatedCoordinate = SSGeoCoordinate(latitude: 43.1111, longitude: -118.2222)

        let marker = RealmReferenceEntity(coordinate: originalCoordinate,
                                          entityKey: entityKey,
                                          name: nil)
        marker.id = markerID
        marker.isTemp = false
        marker.lastUpdatedDate = Date()

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(marker, update: .modified)
        }
        let storeOnlyPOI = GenericLocation(lat: originalCoordinate.latitude,
                                           lon: originalCoordinate.longitude,
                                           name: "Store-Only Name")
        storeOnlyPOI.key = entityKey

        let readMock = MockSpatialReadContract()
        let contractPOI = GenericLocation(lat: originalCoordinate.latitude,
                                          lon: originalCoordinate.longitude,
                                          name: "Contract POI Name")
        contractPOI.key = entityKey
        readMock.poisByKey[entityKey] = contractPOI
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: markerID,
                                                                          location: updatedCoordinate,
                                                                          nickname: nil,
                                                                          estimatedAddress: nil,
                                                                          annotation: nil)

        let refreshedDatabase = try RealmHelper.getDatabaseRealm()
        let updatedMarker = try XCTUnwrap(refreshedDatabase.object(ofType: RealmReferenceEntity.self,
                                                                    forPrimaryKey: markerID))
        XCTAssertEqual(updatedMarker.nickname, "Contract POI Name")
        XCTAssertNil(updatedMarker.entityKey)
        XCTAssertEqual(readMock.poiByKeyCalls, [entityKey])
        XCTAssertEqual(readMock.routesContainingMarkerIDCalls, [markerID])
    }

    func testDefaultSpatialWriteUpdateReferenceEntityWithoutLocationChangeUsesSpatialReadPOILookupForRecents() async throws {
        let markerID = "update-write-no-location-change-\(UUID().uuidString)"
        let entityKey = "update-write-no-location-entity-key-\(UUID().uuidString)"
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 44.6205, baseLongitude: -119.3493)

        let marker = RealmReferenceEntity(coordinate: markerCoordinate,
                                          entityKey: entityKey,
                                          name: "Existing Marker")
        marker.id = markerID
        marker.isTemp = false
        marker.lastUpdatedDate = Date()

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(marker, update: .modified)
        }
        let storeOnlyPOI = GenericLocation(lat: markerCoordinate.latitude,
                                           lon: markerCoordinate.longitude,
                                           name: "Store-Only Name")
        storeOnlyPOI.key = entityKey

        let readMock = MockSpatialReadContract()
        let contractPOI = GenericLocation(lat: markerCoordinate.latitude,
                                          lon: markerCoordinate.longitude,
                                          name: "Contract Recents Name")
        contractPOI.key = entityKey
        readMock.poisByKey[entityKey] = contractPOI
        DataContractRegistry.configure(spatialRead: readMock)

        let runtimeProviders = CloudDispatchProbeRuntimeProviders()
        ReferenceEntityRuntime.configure(with: runtimeProviders.referenceIntegration())

        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: markerID,
                                                                          location: nil,
                                                                          nickname: "Edited Marker",
                                                                          estimatedAddress: nil,
                                                                          annotation: "Updated annotation")

        XCTAssertEqual(readMock.poiByKeyCalls, [entityKey])
        XCTAssertEqual(runtimeProviders.referenceUpdateMarkerParametersCalls, 1)
    }

    func testDefaultSpatialWriteUpdateReferenceEntityNoOpDoesNotDispatchCloudOrRecentsLookups() async throws {
        let markerID = "update-write-no-op-\(UUID().uuidString)"
        let entityKey = "update-write-no-op-entity-key-\(UUID().uuidString)"
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 45.6205, baseLongitude: -120.3493)
        let originalLastUpdatedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let originalLastSelectedDate = Date(timeIntervalSince1970: 1_700_000_100)

        let marker = RealmReferenceEntity(coordinate: markerCoordinate,
                                          entityKey: entityKey,
                                          name: "Unchanged Marker")
        marker.id = markerID
        marker.isTemp = false
        marker.lastUpdatedDate = originalLastUpdatedDate
        marker.lastSelectedDate = originalLastSelectedDate

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(marker, update: .modified)
        }
        let storeOnlyPOI = GenericLocation(lat: markerCoordinate.latitude,
                                           lon: markerCoordinate.longitude,
                                           name: "Store-Only Name")
        storeOnlyPOI.key = entityKey

        let readMock = MockSpatialReadContract()
        let contractPOI = GenericLocation(lat: markerCoordinate.latitude,
                                          lon: markerCoordinate.longitude,
                                          name: "Contract Name")
        contractPOI.key = entityKey
        readMock.poisByKey[entityKey] = contractPOI
        DataContractRegistry.configure(spatialRead: readMock)

        let runtimeProviders = CloudDispatchProbeRuntimeProviders()
        ReferenceEntityRuntime.configure(with: runtimeProviders.referenceIntegration())

        try await DataContractRegistry.spatialWrite.updateReferenceEntity(id: markerID,
                                                                          location: nil,
                                                                          nickname: "Unchanged Marker",
                                                                          estimatedAddress: nil,
                                                                          annotation: nil)

        let refreshedDatabase = try RealmHelper.getDatabaseRealm()
        let refreshedMarker = try XCTUnwrap(refreshedDatabase.object(ofType: RealmReferenceEntity.self,
                                                                      forPrimaryKey: markerID))
        XCTAssertEqual(refreshedMarker.lastUpdatedDate, originalLastUpdatedDate)
        XCTAssertEqual(refreshedMarker.lastSelectedDate, originalLastSelectedDate)
        XCTAssertTrue(readMock.poiByKeyCalls.isEmpty)
        XCTAssertEqual(runtimeProviders.referenceUpdateMarkerParametersCalls, 0)
    }

    func testDefaultSpatialMaintenanceWriteImportReferenceEntityFromCloudHydratesFirstWaypointFromAsyncReadContract() async throws {
        SpatialDataCache.removeAllProviders()
        SpatialDataCache.register(provider: OSMPOISearchProvider())
        SpatialDataCache.register(provider: AddressSearchProvider())
        SpatialDataCache.register(provider: GenericLocationSearchProvider())
        defer { SpatialDataCache.removeAllProviders() }

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

        let firstMarkerID = "import-write-first-\(UUID().uuidString)"
        let secondMarkerID = "import-write-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: firstMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 40.6205, baseLongitude: -115.3493))
        _ = try createPersistedMarker(id: secondMarkerID,
                                      coordinate: makeUniqueCoordinate(baseLatitude: 40.6301, baseLongitude: -115.3402))
        let route = try createPersistedRoute(name: "ImportWriteAsync-\(UUID().uuidString)",
                                             markerIDs: [firstMarkerID, secondMarkerID])

        let importedCoordinate = CLLocationCoordinate2D(latitude: 54.9876, longitude: -128.5432)
        let importPayload = MarkerPayload(id: firstMarkerID,
                                          nickname: "Imported Marker",
                                          annotation: nil,
                                          estimatedAddress: nil,
                                          lastUpdatedDate: Date(),
                                          location: MarkerPayload.LocationPayload(name: "Imported Marker",
                                                                                 address: nil,
                                                                                 coordinate: MarkerPayload.LocationPayload.CoordinatePayload(latitude: importedCoordinate.latitude,
                                                                                                                                             longitude: importedCoordinate.longitude),
                                                                                 entity: nil))
        let markerData = try JSONEncoder().encode(importPayload)
        let markerParameters = try JSONDecoder().decode(MarkerParameters.self, from: markerData)
        let importedEntity = GenericLocation(lat: importedCoordinate.latitude,
                                             lon: importedCoordinate.longitude,
                                             name: "Imported Marker")

        let asyncCoordinate = CLLocationCoordinate2D(latitude: 53.1234, longitude: -127.4567)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[firstMarkerID] = ReferenceEntity(id: firstMarkerID,
                                                                        entityKey: nil,
                                                                        lastUpdatedDate: nil,
                                                                        lastSelectedDate: nil,
                                                                        isNew: false,
                                                                        isTemp: false,
                                                                        coordinate: asyncCoordinate.ssGeoCoordinate,
                                                                        nickname: nil,
                                                                        estimatedAddress: nil,
                                                                        annotation: nil)
        readMock.routesContainingByMarkerID[firstMarkerID] = [route]
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialMaintenanceWrite.importReferenceEntityFromCloud(markerParameters: markerParameters,
                                                                                               entity: importedEntity)

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, firstMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(firstMarkerID))
        XCTAssertEqual(readMock.routesContainingMarkerIDCalls, [firstMarkerID])
    }

    func testDefaultSpatialMaintenanceWriteCleanCorruptReferenceEntitiesHydratesRemainingRouteWaypointFromAsyncReadContract() async throws {
        let corruptMarkerID = "clean-corrupt-first-\(UUID().uuidString)"
        let remainingMarkerID = "clean-corrupt-second-\(UUID().uuidString)"
        let corruptCoordinate = makeUniqueCoordinate(baseLatitude: 41.6205, baseLongitude: -116.3493)
        let remainingCoordinate = makeUniqueCoordinate(baseLatitude: 41.6301, baseLongitude: -116.3402)

        let corruptMarker = RealmReferenceEntity(coordinate: corruptCoordinate, entityKey: nil, name: nil)
        corruptMarker.id = corruptMarkerID
        corruptMarker.isTemp = false
        corruptMarker.lastUpdatedDate = Date()

        let remainingMarker = RealmReferenceEntity(coordinate: remainingCoordinate, entityKey: nil, name: "Remaining")
        remainingMarker.id = remainingMarkerID
        remainingMarker.isTemp = false
        remainingMarker.lastUpdatedDate = Date()

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(corruptMarker, update: .modified)
            database.add(remainingMarker, update: .modified)
        }

        let route = try createPersistedRoute(name: "CleanCorruptAsync-\(UUID().uuidString)",
                                             markerIDs: [corruptMarkerID, remainingMarkerID])

        let asyncCoordinate = CLLocationCoordinate2D(latitude: 52.1234, longitude: -126.4567)
        let readMock = MockSpatialReadContract()
        readMock.referenceEntitiesByID[remainingMarkerID] = ReferenceEntity(id: remainingMarkerID,
                                                                            entityKey: nil,
                                                                            lastUpdatedDate: nil,
                                                                            lastSelectedDate: nil,
                                                                            isNew: false,
                                                                            isTemp: false,
                                                                            coordinate: asyncCoordinate.ssGeoCoordinate,
                                                                            nickname: nil,
                                                                            estimatedAddress: nil,
                                                                            annotation: nil)
        readMock.routesContainingByMarkerID[corruptMarkerID] = [route]
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialMaintenanceWrite.cleanCorruptReferenceEntities()

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, remainingMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertTrue(readMock.referenceEntityByIDCalls.contains(remainingMarkerID))
        XCTAssertTrue(readMock.routesContainingMarkerIDCalls.contains(corruptMarkerID))

        let refreshedDatabase = try RealmHelper.getDatabaseRealm()
        let deletedCorruptMarker = refreshedDatabase.object(ofType: RealmReferenceEntity.self, forPrimaryKey: corruptMarkerID)
        XCTAssertNil(deletedCorruptMarker)
    }

    func testCleanCorruptReferenceEntitiesUsesSpatialReadPOILookupWithoutStoreFallback() async throws {
        try await DataContractRegistry.spatialMaintenanceWrite.removeAllReferenceEntities()

        let markerID = "clean-corrupt-store-only-\(UUID().uuidString)"
        let entityKey = "store-only-poi-key-\(UUID().uuidString)"
        let markerCoordinate = makeUniqueCoordinate(baseLatitude: 39.6205, baseLongitude: -114.3493)

        let marker = RealmReferenceEntity(coordinate: markerCoordinate, entityKey: entityKey, name: nil)
        marker.id = markerID
        marker.isTemp = false
        marker.lastUpdatedDate = Date()

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(marker, update: .modified)
        }
        let storeOnlyPOI = GenericLocation(lat: markerCoordinate.latitude,
                                           lon: markerCoordinate.longitude,
                                           name: "Store-Only POI")
        storeOnlyPOI.key = entityKey

        let readMock = MockSpatialReadContract()
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialMaintenanceWrite.cleanCorruptReferenceEntities()

        let refreshedDatabase = try RealmHelper.getDatabaseRealm()
        let deletedMarker = refreshedDatabase.object(ofType: RealmReferenceEntity.self, forPrimaryKey: markerID)
        XCTAssertNil(deletedMarker)
        XCTAssertTrue(readMock.poiByKeyCalls.contains(entityKey))
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
            database.add(route.realmObject, update: .modified)
        }

        return route
    }

    private func createPersistedRoute(name: String, markerIDs: [String]) throws -> Route {
        var waypoints: [RouteWaypoint] = []
        for (index, markerID) in markerIDs.enumerated() {
            let waypoint = RouteWaypoint(index: index, markerId: markerID)
            waypoints.append(waypoint)
        }

        let route = Route(name: name, description: nil, waypoints: waypoints)
        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(route.realmObject, update: .modified)
        }

        return route
    }

    private func createPersistedMarker(id: String, coordinate: CLLocationCoordinate2D) throws -> RealmReferenceEntity {
        let marker = RealmReferenceEntity(coordinate: coordinate, entityKey: nil, name: "Marker \(id)")
        marker.id = id
        marker.lastUpdatedDate = Date()
        marker.isTemp = false

        let database = try RealmHelper.getDatabaseRealm()
        try database.write {
            database.add(marker, update: .modified)
        }

        return marker
    }

    private func makeUniqueCoordinate(baseLatitude: Double, baseLongitude: Double) -> CLLocationCoordinate2D {
        let offset = Double(abs(UUID().uuidString.hashValue % 1_000)) / 1_000_000.0
        return CLLocationCoordinate2D(latitude: baseLatitude + offset, longitude: baseLongitude - offset)
    }

    private func createRoadEntity(key: String) -> GDASpatialDataResultEntity {
        let parameters = LocationParameters(name: "Road \(key)",
                                            address: nil,
                                            coordinate: CoordinateParameters(latitude: 47.6205, longitude: -122.3493),
                                            entity: nil)
        let road = GDASpatialDataResultEntity(id: key, parameters: parameters)
        road.nameTag = "road"
        return road
    }

    private func createIntersection(key: String,
                                    coordinate: CLLocationCoordinate2D,
                                    roadKeys: [String] = []) -> Intersection {
        let intersection = Intersection()
        intersection.key = key
        intersection.latitude = coordinate.latitude
        intersection.longitude = coordinate.longitude
        roadKeys.forEach { intersection.roadIds.append(IntersectionRoadId(withId: $0)) }
        return intersection
    }

    private func clearAllRoutes() throws {
        let database = try RealmHelper.getDatabaseRealm()
        let routes = database.objects(RealmRoute.self)

        guard !routes.isEmpty else {
            return
        }

        try database.write {
            database.delete(routes)
        }
    }
}
