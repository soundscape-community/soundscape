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
    final class MockSpatialDataStore: SpatialDataStore {
        var referenceEntitiesByKey: [String: RealmReferenceEntity] = [:]
        var referenceEntitiesByEntityKey: [String: RealmReferenceEntity] = [:]
        var referenceEntitiesByLocation: [String: RealmReferenceEntity] = [:]
        var referenceEntitiesNearByLocation: [String: [RealmReferenceEntity]] = [:]
        var referenceEntitiesByGenericLocation: [String: RealmReferenceEntity] = [:]
        var referenceEntitiesToReturn: [RealmReferenceEntity] = []
        var searchResultsByKey: [String: POI] = [:]
        var addedTemporaryReferenceEntityID = "mock-temp-reference-entity-id"
        var routesToReturn: [Route] = []
        var routesByKey: [String: Route] = [:]
        var routesContainingToReturn: [String: [Route]] = [:]
        var roadsByKey: [String: Road] = [:]
        var intersectionsByRoadKey: [String: [Intersection]] = [:]
        var intersectionsByRoadCoordinateKey: [String: Intersection] = [:]
        var intersectionsByRoadRegionKey: [String: [Intersection]] = [:]
        var tilesToReturn: Set<VectorTile> = []
        var tileDataByQuadKey: [String: TileData] = [:]
        var genericLocationsByLookupKey: [String: [POI]] = [:]

        private(set) var referenceEntityByKeyCallKeys: [String] = []
        private(set) var referenceEntityByEntityKeyCallKeys: [String] = []
        private(set) var hasReferenceEntityCallKeys: [String] = []
        private(set) var referenceEntityByLocationCallKeys: [String] = []
        private(set) var referenceEntitiesNearCallKeys: [String] = []
        private(set) var referenceEntityByGenericLocationCallKeys: [String] = []
        private(set) var referenceEntitiesCallCount = 0
        private(set) var recentlySelectedObjectsCallCount = 0
        private(set) var fetchEstimatedAddressCallCount = 0
        private(set) var searchByKeyCallKeys: [String] = []
        private(set) var destinationPOICallKeys: [String] = []
        private(set) var destinationEntityKeyCallKeys: [String] = []
        private(set) var destinationIsTemporaryCallKeys: [String] = []
        private(set) var destinationNicknameCallKeys: [String] = []
        private(set) var destinationEstimatedAddressCallKeys: [String] = []
        private(set) var markReferenceEntitySelectedCallKeys: [String] = []
        private(set) var setReferenceEntityTemporaryCalls: [(id: String, temporary: Bool)] = []
        private(set) var addTemporaryReferenceEntityLocationCallCount = 0
        private(set) var addTemporaryReferenceEntityLocationWithNicknameCallCount = 0
        private(set) var addTemporaryReferenceEntityEntityKeyCallKeys: [String] = []
        private(set) var removeAllTemporaryReferenceEntitiesCallCount = 0
        private(set) var clearNewReferenceEntitiesCallCount = 0
        private(set) var clearNewRoutesCallCount = 0
        private(set) var routesCallCount = 0
        private(set) var routeByKeyCallKeys: [String] = []
        private(set) var routesContainingCallKeys: [String] = []
        private(set) var roadByKeyCallKeys: [String] = []
        private(set) var intersectionsForRoadKeyCallKeys: [String] = []
        private(set) var intersectionForRoadCoordinateCallKeys: [String] = []
        private(set) var intersectionsForRoadRegionCallKeys: [String] = []
        private(set) var tilesCallKeys: [String] = []
        private(set) var tileDataCallQuadKeys: [[String]] = []
        private(set) var genericLocationsNearCallKeys: [String] = []

        func referenceEntityByKey(_ key: String) -> RealmReferenceEntity? {
            referenceEntityByKeyCallKeys.append(key)
            return referenceEntitiesByKey[key]
        }

        func referenceEntityByEntityKey(_ key: String) -> RealmReferenceEntity? {
            referenceEntityByEntityKeyCallKeys.append(key)
            return referenceEntitiesByEntityKey[key]
        }

        func hasReferenceEntity(forEntityKey key: String) -> Bool {
            hasReferenceEntityCallKeys.append(key)
            return referenceEntitiesByEntityKey[key] != nil
        }

        func referenceEntityByLocation(_ coordinate: CLLocationCoordinate2D) -> RealmReferenceEntity? {
            let key = locationKey(for: coordinate)
            referenceEntityByLocationCallKeys.append(key)
            return referenceEntitiesByLocation[key]
        }

        func referenceEntitiesNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance) -> [RealmReferenceEntity] {
            let key = "\(locationKey(for: coordinate))@\(range)"
            referenceEntitiesNearCallKeys.append(key)
            return referenceEntitiesNearByLocation[key] ?? []
        }

        func referenceEntities() -> [RealmReferenceEntity] {
            referenceEntitiesCallCount += 1
            return referenceEntitiesToReturn
        }

        func recentlySelectedObjects() -> [POI] {
            recentlySelectedObjectsCallCount += 1
            return []
        }

        func fetchEstimatedAddress(for location: CLLocation, completion: @escaping (GeocodedAddress?) -> Void) {
            fetchEstimatedAddressCallCount += 1
            completion(nil)
        }

        func searchByKey(_ key: String) -> POI? {
            searchByKeyCallKeys.append(key)
            return searchResultsByKey[key]
        }

        func referenceEntityByGenericLocation(_ location: GenericLocation) -> RealmReferenceEntity? {
            let key = locationKey(for: location.location.coordinate)
            referenceEntityByGenericLocationCallKeys.append(key)
            return referenceEntitiesByGenericLocation[key]
        }

        func destinationPOI(forReferenceID id: String) -> POI? {
            destinationPOICallKeys.append(id)
            return referenceEntitiesByKey[id]?.getPOI()
        }

        func destinationEntityKey(forReferenceID id: String) -> String? {
            destinationEntityKeyCallKeys.append(id)
            return referenceEntitiesByKey[id]?.entityKey
        }

        func destinationIsTemporary(forReferenceID id: String) -> Bool {
            destinationIsTemporaryCallKeys.append(id)
            return referenceEntitiesByKey[id]?.isTemp ?? false
        }

        func destinationNickname(forReferenceID id: String) -> String? {
            destinationNicknameCallKeys.append(id)
            return referenceEntitiesByKey[id]?.nickname
        }

        func destinationEstimatedAddress(forReferenceID id: String) -> String? {
            destinationEstimatedAddressCallKeys.append(id)
            return referenceEntitiesByKey[id]?.estimatedAddress
        }

        func markReferenceEntitySelected(forReferenceID id: String) throws {
            markReferenceEntitySelectedCallKeys.append(id)
        }

        func setReferenceEntityTemporary(forReferenceID id: String, temporary: Bool) throws {
            setReferenceEntityTemporaryCalls.append((id: id, temporary: temporary))
            referenceEntitiesByKey[id]?.isTemp = temporary
        }

        func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String {
            addTemporaryReferenceEntityLocationCallCount += 1
            return addedTemporaryReferenceEntityID
        }

        func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String {
            addTemporaryReferenceEntityLocationWithNicknameCallCount += 1
            return addedTemporaryReferenceEntityID
        }

        func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String {
            addTemporaryReferenceEntityEntityKeyCallKeys.append(entityKey)
            return addedTemporaryReferenceEntityID
        }

        func removeAllTemporaryReferenceEntities() throws {
            removeAllTemporaryReferenceEntitiesCallCount += 1
        }

        func clearNewReferenceEntities() throws {
            clearNewReferenceEntitiesCallCount += 1
        }

        func clearNewRoutes() throws {
            clearNewRoutesCallCount += 1
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

        func roadByKey(_ key: String) -> Road? {
            roadByKeyCallKeys.append(key)
            return roadsByKey[key]
        }

        func intersections(forRoadKey key: String) -> [Intersection] {
            intersectionsForRoadKeyCallKeys.append(key)
            return intersectionsByRoadKey[key] ?? []
        }

        func intersection(forRoadKey key: String, atCoordinate coordinate: CLLocationCoordinate2D) -> Intersection? {
            let lookupKey = roadCoordinateKey(forRoadKey: key, coordinate: coordinate)
            intersectionForRoadCoordinateCallKeys.append(lookupKey)
            return intersectionsByRoadCoordinateKey[lookupKey]
        }

        func intersections(forRoadKey key: String, inRegion region: MKCoordinateRegion) -> [Intersection]? {
            let lookupKey = roadRegionKey(forRoadKey: key, region: region)
            intersectionsForRoadRegionCallKeys.append(lookupKey)
            return intersectionsByRoadRegionKey[lookupKey]
        }

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destinationCoordinate: CLLocationCoordinate2D?) -> Set<VectorTile> {
            let destinationKey: String
            if let destinationCoordinate = destinationCoordinate {
                destinationKey = "\(destinationCoordinate.latitude),\(destinationCoordinate.longitude)"
            } else {
                destinationKey = "nil"
            }

            tilesCallKeys.append("\(forDestinations)|\(forReferences)|\(zoomLevel)|\(destinationKey)")
            return tilesToReturn
        }

        func tileData(for tiles: [VectorTile]) -> [TileData] {
            let quadKeys = tiles.map(\.quadKey)
            tileDataCallQuadKeys.append(quadKeys)
            return quadKeys.compactMap { tileDataByQuadKey[$0] }
        }

        func genericLocationsNear(_ location: CLLocation, range: CLLocationDistance?) -> [POI] {
            let lookupKey = genericLocationLookupKey(location: location, range: range)
            genericLocationsNearCallKeys.append(lookupKey)
            return genericLocationsByLookupKey[lookupKey] ?? []
        }

        private func locationKey(for coordinate: CLLocationCoordinate2D) -> String {
            "\(coordinate.latitude),\(coordinate.longitude)"
        }

        private func roadCoordinateKey(forRoadKey key: String, coordinate: CLLocationCoordinate2D) -> String {
            "\(key)@\(locationKey(for: coordinate))"
        }

        private func roadRegionKey(forRoadKey key: String, region: MKCoordinateRegion) -> String {
            "\(key)@\(locationKey(for: region.center))@\(region.span.latitudeDelta),\(region.span.longitudeDelta)"
        }

        private func genericLocationLookupKey(location: CLLocation, range: CLLocationDistance?) -> String {
            "\(locationKey(for: location.coordinate))@\(range.map(String.init(describing:)) ?? "nil")"
        }
    }

    final class MockSpatialReadContract: SpatialReadContract {
        var routesByKey: [String: Route] = [:]
        var poisByKey: [String: POI] = [:]
        var referenceEntitiesByID: [String: ReferenceEntity] = [:]
        private(set) var routeByKeyCalls: [String] = []
        private(set) var poiByKeyCalls: [String] = []
        private(set) var referenceEntityByIDCalls: [String] = []

        func routes() async -> [Route] { [] }
        func route(byKey key: String) async -> Route? {
            routeByKeyCalls.append(key)
            return routesByKey[key]
        }
        func routeMetadata(byKey key: String) async -> RouteReadMetadata? { nil }
        func routeParameters(byKey key: String, context: RouteParameters.Context) async -> RouteParameters? { nil }
        func routeParametersForBackup() async -> [RouteParameters] { [] }
        func routes(containingMarkerID markerID: String) async -> [Route] { [] }

        func referenceEntity(byID id: String) async -> ReferenceEntity? {
            referenceEntityByIDCalls.append(id)
            return referenceEntitiesByID[id]
        }

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

    override func tearDownWithError() throws {
        SpatialDataStoreRegistry.resetForTesting()
        DataContractRegistry.resetForTesting()
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

    func testRemoveWaypointFromAllRoutesUsesInjectedSpatialStoreLookup() async throws {
        let store = MockSpatialDataStore()
        store.routesContainingToReturn["marker-id"] = []
        SpatialDataStoreRegistry.configure(with: store)
        let readMock = MockSpatialReadContract()

        try await Route.removeWaypointFromAllRoutes(markerId: "marker-id", using: readMock)

        XCTAssertEqual(store.routesContainingCallKeys, ["marker-id"])
    }

    func testDeleteAllUsesInjectedSpatialStoreRoutesList() throws {
        let store = MockSpatialDataStore()
        store.routesToReturn = []
        SpatialDataStoreRegistry.configure(with: store)

        try Route.deleteAll()

        XCTAssertEqual(store.routesCallCount, 1)
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

        let store = MockSpatialDataStore()
        SpatialDataStoreRegistry.configure(with: store)

        let route = Route(from: parameters, firstWaypointCoordinate: explicitCoordinate)

        XCTAssertEqual(route.firstWaypointLatitude ?? 0, explicitCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(route.firstWaypointLongitude ?? 0, explicitCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertTrue(store.referenceEntityByKeyCallKeys.isEmpty)
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

        let store = MockSpatialDataStore()
        let marker = RealmReferenceEntity(coordinate: storeCoordinate)
        marker.id = markerID
        store.referenceEntitiesByKey[markerID] = marker
        SpatialDataStoreRegistry.configure(with: store)

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
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [markerID])
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
        XCTAssertTrue(readMock.referenceEntityByIDCalls.isEmpty)
    }

    func testMarkerParametersInitMarkerIDUsesReferenceEntityLookup() {
        let markerID = "marker-id"
        let marker = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        marker.id = markerID

        let store = MockSpatialDataStore()
        store.referenceEntitiesByKey[markerID] = marker
        let locationLookupKey = "\(marker.latitude),\(marker.longitude)"
        store.referenceEntitiesByLocation[locationLookupKey] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let parameters = MarkerParameters(markerId: markerID)

        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?.id, markerID)
        XCTAssertEqual(store.referenceEntityByKeyCallKeys, [markerID])
        XCTAssertTrue(store.destinationPOICallKeys.isEmpty)
        XCTAssertTrue(store.referenceEntityByLocationCallKeys.contains(locationLookupKey))
    }

    func testMarkerParametersInitGenericLocationUsesInjectedSpatialStoreLocationLookup() {
        let genericLocation = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Generic")
        let expectedCoordinate = genericLocation.location.coordinate
        let locationLookupKey = "\(expectedCoordinate.latitude),\(expectedCoordinate.longitude)"
        let marker = RealmReferenceEntity(coordinate: expectedCoordinate, entityKey: nil)

        let store = MockSpatialDataStore()
        store.referenceEntitiesByLocation[locationLookupKey] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let parameters = MarkerParameters(entity: genericLocation)

        XCTAssertNotNil(parameters)
        XCTAssertTrue(store.referenceEntityByLocationCallKeys.contains(locationLookupKey))
    }

    func testSpatialDataStoreReferenceEntityByEntityKeyDispatchesToInjectedStore() {
        let marker = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        let entityKey = "entity-key"
        let store = MockSpatialDataStore()
        store.referenceEntitiesByEntityKey[entityKey] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let entity = SpatialDataStoreRegistry.store.referenceEntityByEntityKey(entityKey)

        XCTAssertTrue(entity === marker)
        XCTAssertEqual(store.referenceEntityByEntityKeyCallKeys, [entityKey])
    }

    func testSpatialDataStoreReferenceEntityByGenericLocationDispatchesToInjectedStore() {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Generic")
        let marker = RealmReferenceEntity(coordinate: location.location.coordinate)
        let key = "\(location.location.coordinate.latitude),\(location.location.coordinate.longitude)"

        let store = MockSpatialDataStore()
        store.referenceEntitiesByGenericLocation[key] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let entity = SpatialDataStoreRegistry.store.referenceEntityByGenericLocation(location)

        XCTAssertTrue(entity === marker)
        XCTAssertEqual(store.referenceEntityByGenericLocationCallKeys, [key])
    }

    func testSpatialDataStoreReferenceEntitiesNearDispatchesToInjectedStore() {
        let coordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let range = CalloutRangeContext.streetPreview.searchDistance
        let marker = RealmReferenceEntity(coordinate: coordinate)
        let locationLookupKey = "\(coordinate.latitude),\(coordinate.longitude)@\(range)"

        let store = MockSpatialDataStore()
        store.referenceEntitiesNearByLocation[locationLookupKey] = [marker]
        SpatialDataStoreRegistry.configure(with: store)

        let entities = SpatialDataStoreRegistry.store.referenceEntitiesNear(coordinate, range: range)

        XCTAssertEqual(entities.count, 1)
        XCTAssertTrue(entities.first === marker)
        XCTAssertEqual(store.referenceEntitiesNearCallKeys, [locationLookupKey])
    }

    func testSpatialDataStoreTemporaryReferenceEntityOperationsDispatchToInjectedStore() throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Temp")
        let entityKey = "entity-key"
        let expectedID = "temp-id"

        let store = MockSpatialDataStore()
        store.addedTemporaryReferenceEntityID = expectedID
        SpatialDataStoreRegistry.configure(with: store)

        let idFromLocation = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location, estimatedAddress: "Address")
        let idFromNickname = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: location, nickname: "Nickname", estimatedAddress: "Address")
        let idFromEntityKey = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(entityKey: entityKey, estimatedAddress: "Address")
        try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()

        XCTAssertEqual(idFromLocation, expectedID)
        XCTAssertEqual(idFromNickname, expectedID)
        XCTAssertEqual(idFromEntityKey, expectedID)
        XCTAssertEqual(store.addTemporaryReferenceEntityLocationCallCount, 1)
        XCTAssertEqual(store.addTemporaryReferenceEntityLocationWithNicknameCallCount, 1)
        XCTAssertEqual(store.addTemporaryReferenceEntityEntityKeyCallKeys, [entityKey])
        XCTAssertEqual(store.removeAllTemporaryReferenceEntitiesCallCount, 1)
    }

    func testSpatialDataDestinationEntityStoreAsyncTemporaryReferenceEntityOperationsDispatchToInjectedStore() async throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Temp Async")
        let entityKey = "entity-key-async"
        let expectedID = "temp-id-async"

        let store = MockSpatialDataStore()
        store.addedTemporaryReferenceEntityID = expectedID
        SpatialDataStoreRegistry.configure(with: store)

        let destinationStore = SpatialDataDestinationEntityStore()
        let idFromLocation = try await destinationStore.addTemporaryReferenceEntity(location: location, estimatedAddress: "Address")
        let idFromNickname = try await destinationStore.addTemporaryReferenceEntity(location: location, nickname: "Nickname", estimatedAddress: "Address")
        let idFromEntityKey = try await destinationStore.addTemporaryReferenceEntity(entityKey: entityKey, estimatedAddress: "Address")
        try await destinationStore.removeAllTemporaryReferenceEntities()

        XCTAssertEqual(idFromLocation, expectedID)
        XCTAssertEqual(idFromNickname, expectedID)
        XCTAssertEqual(idFromEntityKey, expectedID)
        XCTAssertEqual(store.addTemporaryReferenceEntityLocationCallCount, 1)
        XCTAssertEqual(store.addTemporaryReferenceEntityLocationWithNicknameCallCount, 1)
        XCTAssertEqual(store.addTemporaryReferenceEntityEntityKeyCallKeys, [entityKey])
        XCTAssertEqual(store.removeAllTemporaryReferenceEntitiesCallCount, 1)
    }

    func testSpatialDataDestinationEntityStoreFocusedReadsAndMutationsDispatchToInjectedStore() throws {
        let referenceID = "destination-reference-id"
        let entityKey = "destination-entity-key"
        let nickname = "Destination nickname"
        let estimatedAddress = "123 Main St"
        let marker = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        marker.entityKey = entityKey
        marker.isTemp = true
        marker.nickname = nickname
        marker.estimatedAddress = estimatedAddress

        let store = MockSpatialDataStore()
        store.referenceEntitiesByKey[referenceID] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let destinationStore = SpatialDataDestinationEntityStore()
        let destinationPOI = destinationStore.destinationPOI(forReferenceID: referenceID)
        let destinationEntityKey = destinationStore.destinationEntityKey(forReferenceID: referenceID)
        let destinationIsTemporary = destinationStore.destinationIsTemporary(forReferenceID: referenceID)
        let destinationNickname = destinationStore.destinationNickname(forReferenceID: referenceID)
        let destinationEstimatedAddress = destinationStore.destinationEstimatedAddress(forReferenceID: referenceID)
        try destinationStore.markReferenceEntitySelected(forReferenceID: referenceID)
        try destinationStore.setReferenceEntityTemporary(forReferenceID: referenceID, temporary: false)

        XCTAssertNotNil(destinationPOI)
        XCTAssertEqual(destinationEntityKey, entityKey)
        XCTAssertTrue(destinationIsTemporary)
        XCTAssertEqual(destinationNickname, nickname)
        XCTAssertEqual(destinationEstimatedAddress, estimatedAddress)
        XCTAssertEqual(store.destinationPOICallKeys, [referenceID])
        XCTAssertEqual(store.destinationEntityKeyCallKeys, [referenceID])
        XCTAssertEqual(store.destinationIsTemporaryCallKeys, [referenceID])
        XCTAssertEqual(store.destinationNicknameCallKeys, [referenceID])
        XCTAssertEqual(store.destinationEstimatedAddressCallKeys, [referenceID])
        XCTAssertEqual(store.markReferenceEntitySelectedCallKeys, [referenceID])
        XCTAssertEqual(store.setReferenceEntityTemporaryCalls.count, 1)
        XCTAssertEqual(store.setReferenceEntityTemporaryCalls.first?.id, referenceID)
        XCTAssertFalse(store.setReferenceEntityTemporaryCalls.first?.temporary ?? true)
    }

    func testSpatialDataStoreRoadByKeyDispatchesToInjectedStore() {
        let roadKey = "road-key"
        let roadEntity = createRoadEntity(key: roadKey)
        let store = MockSpatialDataStore()
        store.roadsByKey[roadKey] = roadEntity
        SpatialDataStoreRegistry.configure(with: store)

        let road = SpatialDataStoreRegistry.store.roadByKey(roadKey)

        guard let returnedRoad = road as? GDASpatialDataResultEntity else {
            XCTFail("Expected GDASpatialDataResultEntity road")
            return
        }

        XCTAssertTrue(returnedRoad === roadEntity)
        XCTAssertEqual(store.roadByKeyCallKeys, [roadKey])
    }

    func testSpatialDataStoreIntersectionsForRoadKeyDispatchesToInjectedStore() {
        let roadKey = "road-key"
        let intersection = createIntersection(key: "intersection-key",
                                              coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        let store = MockSpatialDataStore()
        store.intersectionsByRoadKey[roadKey] = [intersection]
        SpatialDataStoreRegistry.configure(with: store)

        let intersections = SpatialDataStoreRegistry.store.intersections(forRoadKey: roadKey)

        XCTAssertEqual(intersections.count, 1)
        XCTAssertTrue(intersections.first === intersection)
        XCTAssertEqual(store.intersectionsForRoadKeyCallKeys, [roadKey])
    }

    func testSpatialDataStoreIntersectionForRoadKeyAtCoordinateDispatchesToInjectedStore() {
        let roadKey = "road-key"
        let coordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let lookupKey = "\(roadKey)@\(coordinate.latitude),\(coordinate.longitude)"
        let intersection = createIntersection(key: "intersection-key", coordinate: coordinate)
        let store = MockSpatialDataStore()
        store.intersectionsByRoadCoordinateKey[lookupKey] = intersection
        SpatialDataStoreRegistry.configure(with: store)

        let result = SpatialDataStoreRegistry.store.intersection(forRoadKey: roadKey, atCoordinate: coordinate)

        XCTAssertTrue(result === intersection)
        XCTAssertEqual(store.intersectionForRoadCoordinateCallKeys, [lookupKey])
    }

    func testSpatialDataStoreIntersectionsForRoadKeyInRegionDispatchesToInjectedStore() {
        let roadKey = "road-key"
        let center = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 500, longitudinalMeters: 500)
        let lookupKey = "\(roadKey)@\(center.latitude),\(center.longitude)@\(region.span.latitudeDelta),\(region.span.longitudeDelta)"
        let intersection = createIntersection(key: "intersection-key", coordinate: center)
        let store = MockSpatialDataStore()
        store.intersectionsByRoadRegionKey[lookupKey] = [intersection]
        SpatialDataStoreRegistry.configure(with: store)

        let intersections = SpatialDataStoreRegistry.store.intersections(forRoadKey: roadKey, inRegion: region)

        XCTAssertEqual(intersections?.count, 1)
        XCTAssertTrue(intersections?.first === intersection)
        XCTAssertEqual(store.intersectionsForRoadRegionCallKeys, [lookupKey])
    }

    func testIntersectionRoadsUseInjectedSpatialStoreLookup() {
        let roadKey = "road-key"
        let roadEntity = createRoadEntity(key: roadKey)
        let intersection = createIntersection(key: "intersection-key",
                                              coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493),
                                              roadKeys: [roadKey])
        let store = MockSpatialDataStore()
        store.roadsByKey[roadKey] = roadEntity
        SpatialDataStoreRegistry.configure(with: store)

        let roads = intersection.roads

        XCTAssertEqual(roads.count, 1)
        XCTAssertEqual(store.roadByKeyCallKeys, [roadKey])
    }

    func testRoadIntersectionsUseInjectedSpatialStoreLookup() {
        let roadKey = "road-key"
        guard let road = createRoadEntity(key: roadKey) as? Road else {
            XCTFail("Expected road-conforming entity")
            return
        }
        let intersection = createIntersection(key: "intersection-key",
                                              coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        let store = MockSpatialDataStore()
        store.intersectionsByRoadKey[roadKey] = [intersection]
        SpatialDataStoreRegistry.configure(with: store)

        let intersections = road.intersections

        XCTAssertEqual(intersections.count, 1)
        XCTAssertTrue(intersections.first === intersection)
        XCTAssertEqual(store.intersectionsForRoadKeyCallKeys, [roadKey])
    }

    func testRoadIntersectionAtCoordinateUsesInjectedSpatialStoreLookup() {
        let roadKey = "road-key"
        let coordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        guard let road = createRoadEntity(key: roadKey) as? Road else {
            XCTFail("Expected road-conforming entity")
            return
        }
        let lookupKey = "\(roadKey)@\(coordinate.latitude),\(coordinate.longitude)"
        let intersection = createIntersection(key: "intersection-key", coordinate: coordinate)
        let store = MockSpatialDataStore()
        store.intersectionsByRoadCoordinateKey[lookupKey] = intersection
        SpatialDataStoreRegistry.configure(with: store)

        let result = road.intersection(atCoordinate: coordinate)

        XCTAssertTrue(result === intersection)
        XCTAssertEqual(store.intersectionForRoadCoordinateCallKeys, [lookupKey])
    }

    func testSpatialDataStoreTilesDispatchesToInjectedStore() {
        let zoomLevel: UInt = 16
        let destinationCoordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)
        let expectedTile = VectorTile(latitude: 47.6205, longitude: -122.3493, zoom: zoomLevel)
        let expectedCallKey = "true|true|\(zoomLevel)|\(destinationCoordinate.latitude),\(destinationCoordinate.longitude)"

        let store = MockSpatialDataStore()
        store.tilesToReturn = [expectedTile]
        SpatialDataStoreRegistry.configure(with: store)

        let tiles = SpatialDataStoreRegistry.store.tiles(forDestinations: true,
                                                         forReferences: true,
                                                         at: zoomLevel,
                                                         destinationCoordinate: destinationCoordinate)

        XCTAssertEqual(tiles.count, 1)
        XCTAssertEqual(tiles.first?.quadKey, expectedTile.quadKey)
        XCTAssertEqual(store.tilesCallKeys, [expectedCallKey])
    }

    func testSpatialDataStoreTileDataDispatchesToInjectedStore() {
        let tile = VectorTile(latitude: 47.6205, longitude: -122.3493, zoom: 16)
        let tileData = TileData()
        tileData.quadkey = tile.quadKey

        let store = MockSpatialDataStore()
        store.tileDataByQuadKey[tile.quadKey] = tileData
        SpatialDataStoreRegistry.configure(with: store)

        let tileDataResults = SpatialDataStoreRegistry.store.tileData(for: [tile])

        XCTAssertEqual(tileDataResults.count, 1)
        XCTAssertTrue(tileDataResults.first === tileData)
        XCTAssertEqual(store.tileDataCallQuadKeys, [[tile.quadKey]])
    }

    func testSpatialDataStoreGenericLocationsNearDispatchesToInjectedStore() {
        let location = CLLocation(latitude: 47.6205, longitude: -122.3493)
        let range = CLLocationDistance(50)
        let lookupKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)@\(String(describing: range))"
        let genericLocation = GenericLocation(lat: location.coordinate.latitude, lon: location.coordinate.longitude, name: "Nearby")

        let store = MockSpatialDataStore()
        store.genericLocationsByLookupKey[lookupKey] = [genericLocation]
        SpatialDataStoreRegistry.configure(with: store)

        let results = SpatialDataStoreRegistry.store.genericLocationsNear(location, range: range)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.key, genericLocation.key)
        XCTAssertEqual(store.genericLocationsNearCallKeys, [lookupKey])
    }

    func testReferenceEntityGetPOIUsesInjectedSpatialStoreSearchLookup() {
        let key = "poi-key"
        let poi = GenericLocation(lat: 47.6205, lon: -122.3493, name: "POI")
        poi.key = key

        let store = MockSpatialDataStore()
        store.searchResultsByKey[key] = poi
        SpatialDataStoreRegistry.configure(with: store)

        let reference = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493),
                                        entityKey: key)
        _ = reference.getPOI()

        XCTAssertEqual(store.searchByKeyCallKeys, [key])
    }

    func testReferenceEntityAddEntityKeyUsesInjectedSpatialStoreLookups() async {
        let missingKey = "missing-entity-key"
        let store = MockSpatialDataStore()
        let spatialRead = MockSpatialReadContract()
        SpatialDataStoreRegistry.configure(with: store)

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

        XCTAssertEqual(store.referenceEntityByEntityKeyCallKeys, [missingKey])
        XCTAssertEqual(store.searchByKeyCallKeys, [missingKey])
    }

    func testReferenceEntityAddLocationUsesInjectedSpatialStoreGenericLocationLookup() async throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Lookup")
        let existingMarker = RealmReferenceEntity(coordinate: location.location.coordinate,
                                             entityKey: nil,
                                             name: "Existing")
        existingMarker.nickname = "Existing"

        let key = "\(location.location.coordinate.latitude),\(location.location.coordinate.longitude)"
        let store = MockSpatialDataStore()
        let spatialRead = MockSpatialReadContract()
        store.referenceEntitiesByGenericLocation[key] = existingMarker
        SpatialDataStoreRegistry.configure(with: store)

        let id = try await RealmReferenceEntity.add(location: location,
                                                    nickname: nil,
                                                    estimatedAddress: nil,
                                                    annotation: nil,
                                                    temporary: true,
                                                    context: "test",
                                                    notify: false,
                                                    using: spatialRead)

        XCTAssertEqual(id, existingMarker.id)
        XCTAssertEqual(store.referenceEntityByGenericLocationCallKeys, [key])
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

    func testRouteAddAsyncUsesInjectedSpatialStoreLocationLookup() async throws {
        let waypointLocation = CLLocation(latitude: 47.6205, longitude: -122.3493)
        let imported = ImportedLocationDetail(nickname: "Waypoint", annotation: "Test waypoint")
        let waypointDetail = LocationDetail(location: waypointLocation, imported: imported, telemetryContext: nil)
        let waypoint = RouteWaypoint(index: 0,
                                     markerId: "initial-marker-id",
                                     importedLocationDetail: waypointDetail)
        let route = Route(name: "RouteAddInjectedStore-\(UUID().uuidString)", description: nil, waypoints: [waypoint])

        let existingMarker = RealmReferenceEntity(coordinate: waypointLocation.coordinate,
                                                  entityKey: nil,
                                                  name: "Existing marker")
        let locationKey = "\(waypointLocation.coordinate.latitude),\(waypointLocation.coordinate.longitude)"
        let store = MockSpatialDataStore()
        store.referenceEntitiesByGenericLocation[locationKey] = existingMarker
        SpatialDataStoreRegistry.configure(with: store)

        try await Route.add(route, using: MockSpatialReadContract())

        let persistedRoute = Route.object(forPrimaryKey: route.id)
        XCTAssertEqual(store.referenceEntityByGenericLocationCallKeys, [locationKey])
        XCTAssertEqual(persistedRoute?.waypoints.ordered.first?.markerId, existingMarker.id)
    }

    func testRouteUpdatePersistsFirstWaypointCoordinatesFromUpdatedWaypointOrder() throws {
        let firstMarkerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6205, baseLongitude: -122.3493)
        let secondMarkerCoordinate = makeUniqueCoordinate(baseLatitude: 47.6301, baseLongitude: -122.3402)
        let firstMarkerID = "update-first-\(UUID().uuidString)"
        let secondMarkerID = "update-second-\(UUID().uuidString)"
        _ = try createPersistedMarker(id: firstMarkerID, coordinate: firstMarkerCoordinate)
        _ = try createPersistedMarker(id: secondMarkerID, coordinate: secondMarkerCoordinate)

        let route = try createPersistedRoute(name: "FirstWaypointUpdate-\(UUID().uuidString)", markerIDs: [firstMarkerID, secondMarkerID])

        guard let reorderedFirst = RouteWaypoint(index: 0, markerId: secondMarkerID),
              let reorderedSecond = RouteWaypoint(index: 1, markerId: firstMarkerID) else {
            XCTFail("Expected persisted marker-backed waypoints")
            return
        }

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
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [secondMarkerID])
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
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialWrite.removeReferenceEntity(id: removedMarkerID)

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, remainingMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [remainingMarkerID])
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
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [firstMarkerID])
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
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialMaintenanceWrite.importReferenceEntityFromCloud(markerParameters: markerParameters,
                                                                                               entity: importedEntity)

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, firstMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [firstMarkerID])
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
        DataContractRegistry.configure(spatialRead: readMock)

        try await DataContractRegistry.spatialMaintenanceWrite.cleanCorruptReferenceEntities()

        let updatedRoute = try XCTUnwrap(Route.object(forPrimaryKey: route.id))
        XCTAssertEqual(updatedRoute.waypoints.ordered.first?.markerId, remainingMarkerID)
        XCTAssertEqual(updatedRoute.firstWaypointLatitude ?? 0, asyncCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(updatedRoute.firstWaypointLongitude ?? 0, asyncCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(readMock.referenceEntityByIDCalls, [remainingMarkerID])

        let refreshedDatabase = try RealmHelper.getDatabaseRealm()
        let deletedCorruptMarker = refreshedDatabase.object(ofType: RealmReferenceEntity.self, forPrimaryKey: corruptMarkerID)
        XCTAssertNil(deletedCorruptMarker)
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
            guard let waypoint = RouteWaypoint(index: index, markerId: markerID) else {
                throw ReferenceEntityError.entityDoesNotExist
            }
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
