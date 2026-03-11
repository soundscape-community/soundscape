// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSDataDomain
import SSGeo
import Testing

@testable import SSDataContracts

private struct TileStub: Hashable {
    let id: Int
}

private struct RouteParametersContextStub: Equatable {
    let includeWaypoints: Bool
}

private struct RouteParametersStub: Equatable {
    let id: String
}

private struct MarkerParametersStub: Equatable {
    let id: String
}

private struct PointOfInterestStub: Equatable {
    let id: String
}

private struct GenericLocationStub: Equatable {
    let id: String
}

private struct NearbyLocationStub {}

private func acceptsRouteParametersReadContract<Contract: SpatialRouteParametersReadContract>(_ contract: Contract) {}
private func acceptsSpatialReadContract<Contract: SpatialReadContract>(_ contract: Contract) {}
private func acceptsReferenceMarkerReadContract<Contract: SpatialReferenceMarkerReadContract>(_ contract: Contract) {}
private func acceptsPointOfInterestReadContract<Contract: SpatialPointOfInterestReadContract>(_ contract: Contract) {}
private func acceptsReferenceWriteContract<Contract: SpatialReferenceWriteContract>(_ contract: Contract) {}
private func acceptsSpatialWriteContract<Contract: SpatialWriteContract>(_ contract: Contract) {}
private func acceptsReferenceMaintenanceWriteContract<Contract: SpatialReferenceMaintenanceWriteContract>(_ contract: Contract) {}
private func acceptsSpatialMaintenanceWriteContract<Contract: SpatialMaintenanceWriteContract>(_ contract: Contract) {}

@MainActor
private final class StorageContractMock: SpatialRouteReadContract,
                                         SpatialRouteParametersReadContract,
                                         SpatialReferenceReadContract,
                                         SpatialReferenceMarkerReadContract,
                                         SpatialPointOfInterestReadContract,
                                         SpatialTileReadContract,
                                         SpatialRouteWriteContract,
                                         SpatialReferenceWriteContract,
                                         SpatialRouteMaintenanceWriteContract,
                                         SpatialReferenceMaintenanceWriteContract,
                                         SpatialAddressMaintenanceWriteContract,
                                         SpatialReadContract,
                                         SpatialWriteContract,
                                         SpatialMaintenanceWriteContract {
    func routes() async -> [Route] { [] }
    func route(byKey key: String) async -> Route? { nil }
    func routeMetadata(byKey key: String) async -> RouteReadMetadata? { nil }
    func routes(containingMarkerID markerID: String) async -> [Route] { [] }
    func routeParameters(byKey key: String, context: RouteParametersContextStub) async -> RouteParametersStub? { nil }
    func routeParametersForBackup() async -> [RouteParametersStub] { [] }

    func referenceEntity(byID id: String) async -> ReferenceEntity? { nil }
    func referenceCallout(byID id: String) async -> ReferenceCalloutReadData? { nil }
    func distanceToClosestLocation(forMarkerID id: String, from location: SSGeoLocation) async -> Double? { nil }
    func referenceMetadata(byID id: String) async -> ReferenceReadMetadata? { nil }
    func referenceMetadata(byEntityKey key: String) async -> ReferenceReadMetadata? { nil }
    func referenceEntity(byEntityKey key: String) async -> ReferenceEntity? { nil }
    func referenceEntity(byCoordinate coordinate: SSGeoCoordinate) async -> ReferenceEntity? { nil }
    func referenceEntities() async -> [ReferenceEntity] { [] }
    func estimatedAddress(near location: SSGeoLocation) async -> EstimatedAddressReadData? { nil }
    func referenceEntities(near coordinate: SSGeoCoordinate, rangeMeters: Double) async -> [ReferenceEntity] { [] }

    func markerParameters(byID id: String) async -> MarkerParametersStub? { nil }
    func markerParameters(byCoordinate coordinate: SSGeoCoordinate) async -> MarkerParametersStub? { nil }
    func markerParameters(byEntityKey key: String) async -> MarkerParametersStub? { nil }
    func markerParametersForBackup() async -> [MarkerParametersStub] { [] }

    func referenceEntity(byGenericLocation location: GenericLocationStub) async -> ReferenceEntity? { nil }
    func recentlySelectedPOIs() async -> [PointOfInterestStub] { [] }
    func poi(byKey key: String) async -> PointOfInterestStub? { nil }

    func tiles(forDestinations: Bool, forReferences: Bool, at zoomLevel: UInt, destination: ReferenceEntity?) async -> Set<TileStub> { [] }
    func genericLocations(near location: SSGeoLocation, rangeMeters: Double?) async -> [NearbyLocationStub] { [] }

    func addRoute(_ route: Route) async throws {}
    func deleteRoute(id: String) async throws {}
    func updateRoute(_ route: Route) async throws {}
    func addReferenceEntity(entityKey: String, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String { "marker-1" }
    func addReferenceEntity(location: GenericLocationStub, nickname: String?, estimatedAddress: String?, annotation: String?) async throws -> String { "marker-2" }
    func updateReferenceEntity(id: String, location: SSGeoCoordinate?, nickname: String?, estimatedAddress: String?, annotation: String?) async throws {}
    func removeReferenceEntity(id: String) async throws {}

    func importRouteFromCloud(_ route: Route) async throws {}
    func removeAllRoutes() async throws {}
    func importReferenceEntityFromCloud(markerParameters: MarkerParametersStub, entity: PointOfInterestStub) async throws {}
    func materializePointOfInterest(from location: LocationParameters) async throws -> PointOfInterestStub {
        PointOfInterestStub(id: location.entity?.lookupInformation ?? location.name)
    }
    func removeAllReferenceEntities() async throws {}
    func clearNewReferenceEntitiesAndRoutes() async throws {}
    func cleanCorruptReferenceEntities() async throws {}

    func restoreCachedAddresses(_ addresses: [AddressCacheRecord]) async throws {}
}

struct SSDataContractsTests {
    @Test
    func addressCacheRecordPreservesValues() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let record = AddressCacheRecord(key: "address-1",
                                        lastSelectedDate: now,
                                        name: "Home",
                                        addressLine: "123 Main St",
                                        streetName: "Main St",
                                        latitude: 47.62,
                                        longitude: -122.34,
                                        centroidLatitude: 47.62,
                                        centroidLongitude: -122.34,
                                        searchString: "home")

        #expect(record.key == "address-1")
        #expect(record.lastSelectedDate == now)
        #expect(record.name == "Home")
        #expect(record.latitude == 47.62)
        #expect(record.longitude == -122.34)
    }

    @Test
    func metadataAndCalloutTypesPreserveFields() {
        let routeMetadata = RouteReadMetadata(id: "route-1", lastUpdatedDate: nil)
        let referenceMetadata = ReferenceReadMetadata(id: "marker-1", lastUpdatedDate: nil)
        let callout = ReferenceCalloutReadData(name: "Marker", superCategory: "places")
        let estimatedAddress = EstimatedAddressReadData(addressLine: "123 Main St",
                                                        streetName: "Main St",
                                                        subThoroughfare: "123")

        #expect(routeMetadata.id == "route-1")
        #expect(referenceMetadata.id == "marker-1")
        #expect(callout.name == "Marker")
        #expect(callout.superCategory == "places")
        #expect(estimatedAddress.addressLine == "123 Main St")
        #expect(estimatedAddress.streetName == "Main St")
        #expect(estimatedAddress.subThoroughfare == "123")
    }

    @Test
    func intersectionRegionStoresCenterAndSpan() {
        let region = SpatialIntersectionRegion(center: .init(latitude: 47.6205, longitude: -122.3493),
                                               latitudeDelta: 0.01,
                                               longitudeDelta: 0.02)

        #expect(region.center.latitude == 47.6205)
        #expect(region.center.longitude == -122.3493)
        #expect(region.latitudeDelta == 0.01)
        #expect(region.longitudeDelta == 0.02)
    }

    @Test
    func geoJSONGeometryParserExtractsTypeAndCoordinates() {
        let point = GeoJSONGeometryParser.coordinates(geoJson: """
        {
            "type": "Point",
            "coordinates": [100.0, 0.0]
        }
        """)
        let line = GeoJSONGeometryParser.coordinates(geoJson: """
        {
            "type": "LineString",
            "coordinates": [
                [100.0, 0.0],
                [101.0, 1.0]
            ]
        }
        """)

        #expect(point.type == .point)
        #expect((point.points as? GAPoint) == [100.0, 0.0])
        #expect(line.type == .lineString)
        #expect((line.points as? GALine) == [[100.0, 0.0], [101.0, 1.0]])
    }

    @Test
    func geoJSONGeometryParserCalculatesCentroidForPolygonData() {
        let centroid = GeoJSONGeometryParser.centroid(geoJson: """
        {
            "type": "Polygon",
            "coordinates": [
                [
                    [100.0, 0.0],
                    [101.0, 0.0],
                    [101.0, 1.0],
                    [100.0, 1.0],
                    [100.0, 0.0]
                ]
            ]
        }
        """)

        #expect(centroid != nil)
        if let centroid {
            #expect(centroid.longitude == 100.5)
            #expect(centroid.latitude == 0.5)
        }
    }

    @MainActor
    @Test
    func storageContractProtocolsSupportUnifiedConformance() async throws {
        let mock = StorageContractMock()
        acceptsSpatialReadContract(mock)
        acceptsRouteParametersReadContract(mock)
        acceptsReferenceMarkerReadContract(mock)
        acceptsPointOfInterestReadContract(mock)
        acceptsSpatialWriteContract(mock)
        acceptsReferenceWriteContract(mock)
        acceptsSpatialMaintenanceWriteContract(mock)
        acceptsReferenceMaintenanceWriteContract(mock)

        let routeRead: any SpatialRouteReadContract = mock
        let referenceRead: any SpatialReferenceReadContract = mock
        let routeWrite: any SpatialRouteWriteContract = mock
        let routeMaintenance: any SpatialRouteMaintenanceWriteContract = mock
        let addressMaintenance: any SpatialAddressMaintenanceWriteContract = mock

        let routes = await routeRead.routes()
        let routeParameters = await mock.routeParameters(byKey: "route-1",
                                                         context: .init(includeWaypoints: true))
        let routeParametersBackup = await mock.routeParametersForBackup()
        let references = await referenceRead.referenceEntities()
        let markerParameters = await mock.markerParameters(byID: "marker-1")
        let markerParametersBackup = await mock.markerParametersForBackup()
        let genericLocationEntity = await mock.referenceEntity(byGenericLocation: .init(id: "location-1"))
        let recentlySelectedPOIs = await mock.recentlySelectedPOIs()
        let poi = await mock.poi(byKey: "poi-1")
        let materializedPOI = try await mock.materializePointOfInterest(from: LocationParameters(
            name: "Imported POI",
            address: nil,
            coordinate: CoordinateParameters(latitude: 47.6205, longitude: -122.3493),
            entity: EntityParameters(source: .osm, lookupInformation: "entity-1")
        ))
        let tiles = await mock.tiles(forDestinations: true, forReferences: true, at: 16, destination: nil)
        let nearbyLocations = await mock.genericLocations(near: .init(coordinate: .init(latitude: 47.6205,
                                                                                          longitude: -122.3493)),
                                                          rangeMeters: 10)

        #expect(routes.isEmpty)
        #expect(routeParameters == nil)
        #expect(routeParametersBackup.isEmpty)
        #expect(references.isEmpty)
        #expect(markerParameters == nil)
        #expect(markerParametersBackup.isEmpty)
        #expect(genericLocationEntity == nil)
        #expect(recentlySelectedPOIs.isEmpty)
        #expect(poi == nil)
        #expect(materializedPOI == PointOfInterestStub(id: "entity-1"))
        #expect(tiles.isEmpty)
        #expect(nearbyLocations.isEmpty)

        try await routeWrite.deleteRoute(id: "route-1")
        let createdMarkerFromEntity = try await mock.addReferenceEntity(entityKey: "entity-1",
                                                                        nickname: nil,
                                                                        estimatedAddress: nil,
                                                                        annotation: nil)
        let createdMarkerFromLocation = try await mock.addReferenceEntity(location: .init(id: "location-1"),
                                                                          nickname: nil,
                                                                          estimatedAddress: nil,
                                                                          annotation: nil)
        try await mock.updateReferenceEntity(id: "marker-1",
                                             location: nil,
                                             nickname: nil,
                                             estimatedAddress: nil,
                                             annotation: nil)
        try await mock.removeReferenceEntity(id: "marker-1")
        try await routeMaintenance.removeAllRoutes()
        try await mock.importReferenceEntityFromCloud(markerParameters: .init(id: "marker-1"),
                                                      entity: .init(id: "poi-1"))
        try await mock.removeAllReferenceEntities()
        try await mock.clearNewReferenceEntitiesAndRoutes()
        try await mock.cleanCorruptReferenceEntities()
        try await addressMaintenance.restoreCachedAddresses([])

        #expect(createdMarkerFromEntity == "marker-1")
        #expect(createdMarkerFromLocation == "marker-2")
    }
}
