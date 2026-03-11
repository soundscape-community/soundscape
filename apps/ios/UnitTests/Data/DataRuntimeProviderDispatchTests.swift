//
//  DataRuntimeProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import SSGeo
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
        var routeAddedIDs: [String] = []
        var routeUpdatedIDs: [String] = []
        var routeDeletedIDs: [String] = []

        var referenceUpdatedMarkerParameters: [MarkerParameters] = []
        var referenceRemovedCloudMarkerIDs: [String] = []
        var referenceRemovedEntityIDs: [String] = []
        var referenceSetDestinationResult = false
        var referenceSetDestinationError: Error?
        var referenceClearError: Error?
        var referenceRemovedCalloutMarkerIDs: [String] = []
        var referenceProcessedEventNames: [String] = []

        var destinationLocation: CLLocation?
        var routeGuidanceActive = false
        var routeOrTourGuidanceActive = false
        var beaconCalloutBlocked = false
        var destinationProcessedEventNames: [String] = []

        var spatialDataContextLocation: CLLocation?
        var didPerformInitialCloudSync = false
        var didClearCalloutHistory = false
        var appIsInNormalState = false
        var updatedAudioEngineLocations: [CLLocation] = []
        var spatialDataContextProcessedEventNames: [String] = []

        func routeIntegration() -> RouteRuntime.Integration {
            .init(
                currentUserLocation: { [self] in routeLocation },
                activeRouteDatabaseID: { [self] in routeID },
                deactivateActiveBehavior: { [self] in routeDeactivateCount += 1 },
                storeRouteInCloud: { [self] route in routeStored.append(route) },
                updateRouteInCloud: { [self] route in routeUpdated.append(route) },
                removeRouteFromCloud: { [self] route in routeRemoved.append(route) },
                currentMotionActivityRawValue: { [self] in routeMotion },
                didAddRoute: { [self] id in routeAddedIDs.append(id) },
                didUpdateRoute: { [self] id in routeUpdatedIDs.append(id) },
                didDeleteRoute: { [self] id in routeDeletedIDs.append(id) }
            )
        }

        func referenceIntegration() -> ReferenceEntityRuntime.Integration {
            .init(
                updateReferenceInCloud: { [self] markerParameters in
                    referenceUpdatedMarkerParameters.append(markerParameters)
                },
                removeReferenceFromCloud: { [self] markerID in
                    referenceRemovedCloudMarkerIDs.append(markerID)
                },
                didRemoveReferenceEntity: { [self] id in
                    referenceRemovedEntityIDs.append(id)
                },
                setDestinationTemporaryIfMatchingID: { [self] _ in
                    if let referenceSetDestinationError {
                        throw referenceSetDestinationError
                    }

                    return referenceSetDestinationResult
                },
                clearDestinationForCacheReset: { [self] in
                    if let referenceClearError {
                        throw referenceClearError
                    }
                },
                removeCalloutHistoryForMarkerID: { [self] markerID in
                    referenceRemovedCalloutMarkerIDs.append(markerID)
                },
                processEvent: { [self] event in
                    referenceProcessedEventNames.append(event.name)
                }
            )
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

        func destinationManagerProcessEvent(_ event: Event) {
            destinationProcessedEventNames.append(event.name)
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

        func spatialDataContextProcessEvent(_ event: Event) {
            spatialDataContextProcessedEventNames.append(event.name)
        }
    }

    override func tearDown() {
        SpatialDataEntityDebugRuntime.resetForTesting()
        RouteRuntime.resetForTesting()
        ReferenceEntityRuntime.resetForTesting()
        RealmMigrationRuntime.resetForTesting()
        DataRuntimeProviderRegistry.resetForTesting()
        super.tearDown()
    }

    func testRouteRuntimeDispatchesToConfiguredProvider() {
        let provider = MockDataRuntimeProviders()
        let location = CLLocation(latitude: 47.62, longitude: -122.35)
        provider.routeLocation = location
        provider.routeID = "route-123"
        provider.routeMotion = "walking"
        RouteRuntime.configure(with: provider.routeIntegration())

        let route = Route()

        XCTAssertEqual(RouteRuntime.currentUserLocation(), location)
        XCTAssertEqual(RouteRuntime.activeRouteDatabaseID(), "route-123")
        XCTAssertEqual(RouteRuntime.currentMotionActivityRawValue(), "walking")

        RouteRuntime.deactivateActiveBehavior()
        RouteRuntime.storeRouteInCloud(route)
        RouteRuntime.updateRouteInCloud(route)
        RouteRuntime.removeRouteFromCloud(route)
        RouteRuntime.didAddRoute(id: "route-added")
        RouteRuntime.didUpdateRoute(id: "route-updated")
        RouteRuntime.didDeleteRoute(id: "route-deleted")

        XCTAssertEqual(provider.routeDeactivateCount, 1)
        XCTAssertEqual(provider.routeStored.count, 1)
        XCTAssertEqual(provider.routeUpdated.count, 1)
        XCTAssertEqual(provider.routeRemoved.count, 1)
        XCTAssertEqual(provider.routeAddedIDs, ["route-added"])
        XCTAssertEqual(provider.routeUpdatedIDs, ["route-updated"])
        XCTAssertEqual(provider.routeDeletedIDs, ["route-deleted"])
    }

    func testReferenceEntityRuntimeDispatchesAndPropagatesErrors() async {
        let provider = MockDataRuntimeProviders()
        provider.referenceSetDestinationResult = true
        ReferenceEntityRuntime.configure(with: provider.referenceIntegration())

        let entity = ReferenceEntity(id: UUID().uuidString,
                                     entityKey: nil,
                                     lastUpdatedDate: nil,
                                     lastSelectedDate: nil,
                                     isNew: false,
                                     isTemp: false,
                                     coordinate: SSGeoCoordinate(latitude: 47.60, longitude: -122.34),
                                     nickname: nil,
                                     estimatedAddress: nil,
                                     annotation: nil)

        XCTAssertTrue((try? ReferenceEntityRuntime.setDestinationTemporaryIfMatchingID("destination-1")) ?? false)

        let cloudEntity = GenericLocation(lat: 47.63,
                                          lon: -122.32,
                                          name: "Cloud Marker")
        if let markerParameters = MarkerParameters(entity: cloudEntity,
                                                   markerId: entity.id,
                                                   estimatedAddress: nil,
                                                   nickname: entity.nickname,
                                                   annotation: entity.annotation,
                                                   lastUpdatedDate: entity.lastUpdatedDate) {
            ReferenceEntityRuntime.updateReferenceInCloud(markerParameters)
        } else {
            XCTFail("Expected marker parameters for cloud dispatch")
            return
        }
        ReferenceEntityRuntime.removeReferenceFromCloud(markerID: entity.id)
        ReferenceEntityRuntime.didRemoveReferenceEntity(id: entity.id)
        ReferenceEntityRuntime.removeCalloutHistoryForMarkerID("marker-1")
        ReferenceEntityRuntime.processEvent(BehaviorActivatedEvent())

        XCTAssertEqual(provider.referenceUpdatedMarkerParameters.count, 1)
        XCTAssertEqual(provider.referenceRemovedCloudMarkerIDs, [entity.id])
        XCTAssertEqual(provider.referenceRemovedEntityIDs, [entity.id])
        XCTAssertEqual(provider.referenceRemovedCalloutMarkerIDs, ["marker-1"])
        XCTAssertEqual(provider.referenceProcessedEventNames, [BehaviorActivatedEvent().name])

        provider.referenceSetDestinationError = MockError.expected
        XCTAssertThrowsError(try ReferenceEntityRuntime.setDestinationTemporaryIfMatchingID("destination-2"))

        provider.referenceClearError = MockError.expected
        do {
            try await ReferenceEntityRuntime.clearDestinationForCacheReset()
            XCTFail("Expected clearDestinationForCacheReset to throw")
        } catch {
            // expected
        }
    }

    func testSpatialDataEntityDebugRuntimeAndDestinationRuntimeDispatch() {
        let provider = MockDataRuntimeProviders()
        let location = CLLocation(latitude: 47.64, longitude: -122.36)
        provider.destinationLocation = location
        provider.routeGuidanceActive = true
        provider.routeOrTourGuidanceActive = true
        provider.beaconCalloutBlocked = true
        SpatialDataEntityDebugRuntime.configure(with: .init(currentUserLocation: { location }))
        DataRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(SpatialDataEntityDebugRuntime.currentUserLocation(), location)
        XCTAssertEqual(DestinationManagerRuntime.currentUserLocation(), location)
        XCTAssertTrue(DestinationManagerRuntime.isRouteGuidanceActive())
        XCTAssertTrue(DestinationManagerRuntime.isRouteOrTourGuidanceActive())
        XCTAssertTrue(DestinationManagerRuntime.isBeaconCalloutGeneratorBlocked())

        DestinationManagerRuntime.processEvent(BehaviorActivatedEvent())
        XCTAssertEqual(provider.destinationProcessedEventNames, [BehaviorActivatedEvent().name])
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
        SpatialDataContextRuntime.processEvent(BehaviorActivatedEvent())

        wait(for: [syncExpectation], timeout: 1.0)
        XCTAssertTrue(provider.didPerformInitialCloudSync)
        XCTAssertTrue(provider.didClearCalloutHistory)
        XCTAssertEqual(provider.updatedAudioEngineLocations.count, 1)
        XCTAssertEqual(provider.updatedAudioEngineLocations.first, location)
        XCTAssertEqual(provider.spatialDataContextProcessedEventNames, [BehaviorActivatedEvent().name])
    }

    func testRealmMigrationRuntimeDispatchesToConfiguredIntegration() {
        var migratedRealmNames: [String] = []
        RealmMigrationRuntime.configure(
            with: .init(trackMigrationFailure: { realmName in
                migratedRealmNames.append(realmName)
            })
        )

        RealmMigrationRuntime.trackMigrationFailure(forRealmNamed: "Cache.realm")

        XCTAssertEqual(migratedRealmNames, ["Cache.realm"])
    }

    func testRuntimeResetClearsInjectedProviders() {
        let provider = MockDataRuntimeProviders()
        provider.routeLocation = CLLocation(latitude: 47.66, longitude: -122.38)
        SpatialDataEntityDebugRuntime.configure(with: .init(currentUserLocation: { provider.routeLocation }))
        RouteRuntime.configure(with: provider.routeIntegration())
        DataRuntimeProviderRegistry.configure(with: provider)

        XCTAssertNotNil(SpatialDataEntityDebugRuntime.currentUserLocation())
        XCTAssertNotNil(RouteRuntime.currentUserLocation())

        SpatialDataEntityDebugRuntime.resetForTesting()
        RouteRuntime.resetForTesting()
        DataRuntimeProviderRegistry.resetForTesting()

        XCTAssertNil(SpatialDataEntityDebugRuntime.currentUserLocation())
        XCTAssertNil(RouteRuntime.currentUserLocation())
        XCTAssertFalse(DestinationManagerRuntime.isRouteGuidanceActive())
        XCTAssertFalse(SpatialDataContextRuntime.isApplicationInNormalState())
    }
}
