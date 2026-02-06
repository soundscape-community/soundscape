//
//  DataRuntimeProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class DataRuntimeProviderDispatchTests: XCTestCase {
    private enum MockError: Error {
        case expected
    }

    private final class MockDataRuntimeProviders: DataRuntimeProviders {
        var routeLocation: CLLocation?
        var routeID: String?
        var routeMotion: String = "test-motion"
        var routeDeactivateCount = 0
        var routeStored: [Route] = []
        var routeUpdated: [Route] = []
        var routeRemoved: [Route] = []

        var referenceLocation: CLLocation?
        var referenceStored: [ReferenceEntity] = []
        var referenceUpdated: [ReferenceEntity] = []
        var referenceRemoved: [ReferenceEntity] = []
        var referenceSetDestinationResult = false
        var referenceSetDestinationError: Error?
        var referenceClearError: Error?
        var referenceRemovedMarkerIDs: [String] = []

        var spatialDataEntityLocation: CLLocation?

        var destinationLocation: CLLocation?
        var routeGuidanceActive = false
        var routeOrTourGuidanceActive = false
        var beaconCalloutBlocked = false

        var spatialDataContextLocation: CLLocation?
        var didPerformInitialCloudSync = false
        var didClearCalloutHistory = false
        var appIsInNormalState = false
        var updatedAudioEngineLocations: [CLLocation] = []

        func routeCurrentUserLocation() -> CLLocation? {
            routeLocation
        }

        func routeActiveRouteDatabaseID() -> String? {
            routeID
        }

        func routeDeactivateActiveBehavior() {
            routeDeactivateCount += 1
        }

        func routeStoreInCloud(_ route: Route) {
            routeStored.append(route)
        }

        func routeUpdateInCloud(_ route: Route) {
            routeUpdated.append(route)
        }

        func routeRemoveFromCloud(_ route: Route) {
            routeRemoved.append(route)
        }

        func routeCurrentMotionActivityRawValue() -> String {
            routeMotion
        }

        func referenceCurrentUserLocation() -> CLLocation? {
            referenceLocation
        }

        func referenceStoreInCloud(_ entity: ReferenceEntity) {
            referenceStored.append(entity)
        }

        func referenceUpdateInCloud(_ entity: ReferenceEntity) {
            referenceUpdated.append(entity)
        }

        func referenceRemoveFromCloud(_ entity: ReferenceEntity) {
            referenceRemoved.append(entity)
        }

        func referenceSetDestinationTemporaryIfMatchingID(_ id: String) throws -> Bool {
            if let referenceSetDestinationError {
                throw referenceSetDestinationError
            }

            return referenceSetDestinationResult
        }

        func referenceClearDestinationForCacheReset() throws {
            if let referenceClearError {
                throw referenceClearError
            }
        }

        func referenceRemoveCalloutHistoryForMarkerID(_ markerID: String) {
            referenceRemovedMarkerIDs.append(markerID)
        }

        func spatialDataEntityCurrentUserLocation() -> CLLocation? {
            spatialDataEntityLocation
        }

        func destinationManagerCurrentUserLocation() -> CLLocation? {
            destinationLocation
        }

        func destinationManagerIsRouteGuidanceActive() -> Bool {
            routeGuidanceActive
        }

        func destinationManagerIsRouteOrTourGuidanceActive() -> Bool {
            routeOrTourGuidanceActive
        }

        func destinationManagerIsBeaconCalloutGeneratorBlocked() -> Bool {
            beaconCalloutBlocked
        }

        func spatialDataContextCurrentUserLocation() -> CLLocation? {
            spatialDataContextLocation
        }

        func spatialDataContextPerformInitialCloudSync(_ completion: @escaping () -> Void) {
            didPerformInitialCloudSync = true
            completion()
        }

        func spatialDataContextClearCalloutHistory() {
            didClearCalloutHistory = true
        }

        func spatialDataContextIsApplicationInNormalState() -> Bool {
            appIsInNormalState
        }

        func spatialDataContextUpdateAudioEngineUserLocation(_ location: CLLocation) {
            updatedAudioEngineLocations.append(location)
        }
    }

    override func tearDown() {
        DataRuntimeProviderRegistry.resetForTesting()
        super.tearDown()
    }

    func testRouteRuntimeDispatchesToConfiguredProvider() {
        let provider = MockDataRuntimeProviders()
        let location = CLLocation(latitude: 47.62, longitude: -122.35)
        provider.routeLocation = location
        provider.routeID = "route-123"
        provider.routeMotion = "walking"
        DataRuntimeProviderRegistry.configure(with: provider)

        let route = Route()

        XCTAssertEqual(RouteRuntime.currentUserLocation(), location)
        XCTAssertEqual(RouteRuntime.activeRouteDatabaseID(), "route-123")
        XCTAssertEqual(RouteRuntime.currentMotionActivityRawValue(), "walking")

        RouteRuntime.deactivateActiveBehavior()
        RouteRuntime.storeRouteInCloud(route)
        RouteRuntime.updateRouteInCloud(route)
        RouteRuntime.removeRouteFromCloud(route)

        XCTAssertEqual(provider.routeDeactivateCount, 1)
        XCTAssertEqual(provider.routeStored.count, 1)
        XCTAssertEqual(provider.routeUpdated.count, 1)
        XCTAssertEqual(provider.routeRemoved.count, 1)
    }

    func testReferenceEntityRuntimeDispatchesAndPropagatesErrors() {
        let provider = MockDataRuntimeProviders()
        let location = CLLocation(latitude: 47.61, longitude: -122.33)
        provider.referenceLocation = location
        provider.referenceSetDestinationResult = true
        DataRuntimeProviderRegistry.configure(with: provider)

        let entity = ReferenceEntity(coordinate: CLLocationCoordinate2D(latitude: 47.60, longitude: -122.34))

        XCTAssertEqual(ReferenceEntityRuntime.currentUserLocation(), location)
        XCTAssertTrue((try? ReferenceEntityRuntime.setDestinationTemporaryIfMatchingID("destination-1")) ?? false)

        ReferenceEntityRuntime.storeReferenceInCloud(entity)
        ReferenceEntityRuntime.updateReferenceInCloud(entity)
        ReferenceEntityRuntime.removeReferenceFromCloud(entity)
        ReferenceEntityRuntime.removeCalloutHistoryForMarkerID("marker-1")

        XCTAssertEqual(provider.referenceStored.count, 1)
        XCTAssertEqual(provider.referenceUpdated.count, 1)
        XCTAssertEqual(provider.referenceRemoved.count, 1)
        XCTAssertEqual(provider.referenceRemovedMarkerIDs, ["marker-1"])

        provider.referenceSetDestinationError = MockError.expected
        XCTAssertThrowsError(try ReferenceEntityRuntime.setDestinationTemporaryIfMatchingID("destination-2"))

        provider.referenceClearError = MockError.expected
        XCTAssertThrowsError(try ReferenceEntityRuntime.clearDestinationForCacheReset())
    }

    func testSpatialDataEntityAndDestinationRuntimeDispatch() {
        let provider = MockDataRuntimeProviders()
        let location = CLLocation(latitude: 47.64, longitude: -122.36)
        provider.spatialDataEntityLocation = location
        provider.destinationLocation = location
        provider.routeGuidanceActive = true
        provider.routeOrTourGuidanceActive = true
        provider.beaconCalloutBlocked = true
        DataRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(SpatialDataEntityRuntime.currentUserLocation(), location)
        XCTAssertEqual(DestinationManagerRuntime.currentUserLocation(), location)
        XCTAssertTrue(DestinationManagerRuntime.isRouteGuidanceActive())
        XCTAssertTrue(DestinationManagerRuntime.isRouteOrTourGuidanceActive())
        XCTAssertTrue(DestinationManagerRuntime.isBeaconCalloutGeneratorBlocked())
    }

    func testSpatialDataContextRuntimeDispatchesToProvider() {
        let provider = MockDataRuntimeProviders()
        let location = CLLocation(latitude: 47.65, longitude: -122.37)
        provider.spatialDataContextLocation = location
        provider.appIsInNormalState = true
        DataRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(SpatialDataContextRuntime.currentUserLocation(), location)
        XCTAssertTrue(SpatialDataContextRuntime.isApplicationInNormalState())

        let syncExpectation = expectation(description: "initial cloud sync completion")
        SpatialDataContextRuntime.performInitialCloudSync {
            syncExpectation.fulfill()
        }

        SpatialDataContextRuntime.clearCalloutHistory()
        SpatialDataContextRuntime.updateAudioEngineUserLocation(location)

        wait(for: [syncExpectation], timeout: 1.0)
        XCTAssertTrue(provider.didPerformInitialCloudSync)
        XCTAssertTrue(provider.didClearCalloutHistory)
        XCTAssertEqual(provider.updatedAudioEngineLocations.count, 1)
        XCTAssertEqual(provider.updatedAudioEngineLocations.first, location)
    }

    func testProviderResetClearsInjectedProvider() {
        let provider = MockDataRuntimeProviders()
        provider.routeLocation = CLLocation(latitude: 47.66, longitude: -122.38)
        DataRuntimeProviderRegistry.configure(with: provider)

        XCTAssertNotNil(RouteRuntime.currentUserLocation())

        DataRuntimeProviderRegistry.resetForTesting()

        XCTAssertNil(RouteRuntime.currentUserLocation())
        XCTAssertFalse(DestinationManagerRuntime.isRouteGuidanceActive())
        XCTAssertFalse(SpatialDataContextRuntime.isApplicationInNormalState())
    }
}
