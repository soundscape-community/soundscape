//
//  RouteStorageProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import MapKit
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
        var addedReferenceEntityID = "mock-added-reference-entity-id"
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
        private(set) var referenceEntityByLocationCallKeys: [String] = []
        private(set) var referenceEntitiesNearCallKeys: [String] = []
        private(set) var referenceEntityByGenericLocationCallKeys: [String] = []
        private(set) var referenceEntitiesCallCount = 0
        private(set) var searchByKeyCallKeys: [String] = []
        private(set) var addReferenceEntityCallCount = 0
        private(set) var addTemporaryReferenceEntityLocationCallCount = 0
        private(set) var addTemporaryReferenceEntityLocationWithNicknameCallCount = 0
        private(set) var addTemporaryReferenceEntityEntityKeyCallKeys: [String] = []
        private(set) var removeAllTemporaryReferenceEntitiesCallCount = 0
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

        func searchByKey(_ key: String) -> POI? {
            searchByKeyCallKeys.append(key)
            return searchResultsByKey[key]
        }

        func addReferenceEntity(detail: LocationDetail, telemetryContext: String?, notify: Bool) throws -> String {
            addReferenceEntityCallCount += 1
            return addedReferenceEntityID
        }

        func referenceEntityByGenericLocation(_ location: GenericLocation) -> RealmReferenceEntity? {
            let key = locationKey(for: location.location.coordinate)
            referenceEntityByGenericLocationCallKeys.append(key)
            return referenceEntitiesByGenericLocation[key]
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

        func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: RealmReferenceEntity?) -> Set<VectorTile> {
            let destinationKey: String
            if let destination = destination {
                destinationKey = "\(destination.latitude),\(destination.longitude)"
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
        let marker = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
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
        let marker = RealmReferenceEntity(coordinate: expectedCoordinate, entityKey: nil)

        let store = MockSpatialDataStore()
        store.referenceEntitiesByLocation[locationLookupKey] = marker
        SpatialDataStoreRegistry.configure(with: store)

        let parameters = MarkerParameters(entity: genericLocation)

        XCTAssertNotNil(parameters)
        XCTAssertEqual(store.referenceEntityByLocationCallKeys, [locationLookupKey])
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
        let destination = RealmReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493))
        let expectedTile = VectorTile(latitude: 47.6205, longitude: -122.3493, zoom: zoomLevel)
        let expectedCallKey = "true|true|\(zoomLevel)|\(destination.latitude),\(destination.longitude)"

        let store = MockSpatialDataStore()
        store.tilesToReturn = [expectedTile]
        SpatialDataStoreRegistry.configure(with: store)

        let tiles = SpatialDataStoreRegistry.store.tiles(forDestinations: true,
                                                         forReferences: true,
                                                         at: zoomLevel,
                                                         destination: destination)

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

    func testReferenceEntityAddEntityKeyUsesInjectedSpatialStoreLookups() {
        let missingKey = "missing-entity-key"
        let store = MockSpatialDataStore()
        SpatialDataStoreRegistry.configure(with: store)

        XCTAssertThrowsError(try RealmReferenceEntity.add(entityKey: missingKey,
                                                     nickname: nil,
                                                     estimatedAddress: nil,
                                                     annotation: nil,
                                                     temporary: false,
                                                     context: nil,
                                                     notify: false)) { error in
            guard case ReferenceEntityError.entityDoesNotExist = error else {
                XCTFail("Expected entityDoesNotExist, received: \(error)")
                return
            }
        }

        XCTAssertEqual(store.referenceEntityByEntityKeyCallKeys, [missingKey])
        XCTAssertEqual(store.searchByKeyCallKeys, [missingKey])
    }

    func testReferenceEntityAddLocationUsesInjectedSpatialStoreGenericLocationLookup() throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Lookup")
        let existingMarker = RealmReferenceEntity(coordinate: location.location.coordinate,
                                             entityKey: nil,
                                             name: "Existing")
        existingMarker.nickname = "Existing"

        let key = "\(location.location.coordinate.latitude),\(location.location.coordinate.longitude)"
        let store = MockSpatialDataStore()
        store.referenceEntitiesByGenericLocation[key] = existingMarker
        SpatialDataStoreRegistry.configure(with: store)

        let id = try RealmReferenceEntity.add(location: location,
                                         nickname: nil,
                                         estimatedAddress: nil,
                                         annotation: nil,
                                         temporary: true,
                                         context: "test",
                                         notify: false)

        XCTAssertEqual(id, existingMarker.id)
        XCTAssertEqual(store.referenceEntityByGenericLocationCallKeys, [key])
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
        let routes = database.objects(Route.self)

        guard !routes.isEmpty else {
            return
        }

        try database.write {
            database.delete(routes)
        }
    }
}
