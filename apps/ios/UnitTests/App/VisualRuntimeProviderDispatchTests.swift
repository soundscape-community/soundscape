//
//  VisualRuntimeProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import SSGeo
@testable import Soundscape

@MainActor
final class VisualRuntimeProviderDispatchTests: XCTestCase {
    private func location(latitude: Double, longitude: Double) -> SSGeoLocation {
        SSGeoLocation(coordinate: SSGeoCoordinate(latitude: latitude, longitude: longitude))
    }

    private final class MockVisualRuntimeProviders: VisualRuntimeProviders {
        var initialLocation: SSGeoLocation?
        var geofenceResult = false
        var receivedGeofenceInputs: [SSGeoLocation] = []
        var routeGuidanceLookupCount = 0
        var guidedTourLookupCount = 0
        var playAudioResult: AudioPlayerIdentifier?
        var playedAudioURLs: [URL] = []
        var stoppedAudioIDs: [AudioPlayerIdentifier] = []
        var customBehaviorActive = false
        var activateCustomBehaviorCount = 0
        var deactivateCustomBehaviorCount = 0
        var processedEventNames: [String] = []
        var currentUserLocation: CLLocation?
        var isOffline = false
        var hushRequests: [Bool] = []
        var checkServiceConnectionResult = false
        var checkServiceConnectionCallCount = 0
        var spatialDataLookupCount = 0
        var motionActivityLookupCount = 0

        func userLocationStoreInitialUserLocation() -> SSGeoLocation? {
            initialLocation
        }

        func beaconDetailIsUserWithinDestinationGeofence(_ userLocation: SSGeoLocation) -> Bool {
            receivedGeofenceInputs.append(userLocation)
            return geofenceResult
        }

        func beaconStoreDestinationManager() -> DestinationManagerProtocol? {
            nil
        }

        func beaconStoreActiveRouteGuidance() -> RouteGuidance? {
            routeGuidanceLookupCount += 1
            return nil
        }

        func routeGuidanceStateStoreActiveRouteGuidance() -> RouteGuidance? {
            routeGuidanceLookupCount += 1
            return nil
        }

        func guidedTourStateStoreActiveTour() -> GuidedTour? {
            guidedTourLookupCount += 1
            return nil
        }

        func audioFileStorePlay(_ url: URL) -> AudioPlayerIdentifier? {
            playedAudioURLs.append(url)
            return playAudioResult
        }

        func audioFileStoreStop(_ id: AudioPlayerIdentifier) {
            stoppedAudioIDs.append(id)
        }

        func visualIsCustomBehaviorActive() -> Bool {
            customBehaviorActive
        }

        func visualActivateCustomBehavior(_ behavior: Behavior) {
            activateCustomBehaviorCount += 1
        }

        func visualDeactivateCustomBehavior() {
            deactivateCustomBehaviorCount += 1
        }

        func visualProcessEvent(_ event: Event) {
            processedEventNames.append(event.name)
        }

        func visualCurrentUserLocation() -> CLLocation? {
            currentUserLocation
        }

        func visualIsOffline() -> Bool {
            isOffline
        }

        func visualHushEventProcessor(playSound: Bool) {
            hushRequests.append(playSound)
        }

        func visualCheckSpatialServiceConnection(_ completion: @escaping (Bool) -> Void) {
            checkServiceConnectionCallCount += 1
            completion(checkServiceConnectionResult)
        }

        func visualSpatialDataContext() -> SpatialDataProtocol? {
            spatialDataLookupCount += 1
            return nil
        }

        func visualMotionActivityContext() -> MotionActivityProtocol? {
            motionActivityLookupCount += 1
            return nil
        }
    }

    override func tearDown() {
        VisualRuntimeProviderRegistry.resetForTesting()
        super.tearDown()
    }

    func testUserLocationStoreRuntimeDispatchesToConfiguredProvider() {
        let provider = MockVisualRuntimeProviders()
        let expected = location(latitude: 47.6205, longitude: -122.3493)
        provider.initialLocation = expected
        VisualRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(UserLocationStoreRuntime.initialUserLocation(), expected)
    }

    func testBeaconDetailRuntimeDispatchesToConfiguredProvider() {
        let provider = MockVisualRuntimeProviders()
        provider.geofenceResult = true
        VisualRuntimeProviderRegistry.configure(with: provider)

        let userLocation = location(latitude: 47.6205, longitude: -122.3493)
        XCTAssertTrue(BeaconDetailRuntime.isUserWithinDestinationGeofence(userLocation))
        XCTAssertEqual(provider.receivedGeofenceInputs, [userLocation])
    }

    func testProviderResetClearsInjectedProvider() {
        let provider = MockVisualRuntimeProviders()
        provider.initialLocation = location(latitude: 47.61, longitude: -122.33)
        provider.geofenceResult = true
        VisualRuntimeProviderRegistry.configure(with: provider)

        XCTAssertNotNil(UserLocationStoreRuntime.initialUserLocation())
        XCTAssertTrue(BeaconDetailRuntime.isUserWithinDestinationGeofence(location(latitude: 47.62, longitude: -122.34)))

        VisualRuntimeProviderRegistry.resetForTesting()

        XCTAssertNil(UserLocationStoreRuntime.initialUserLocation())
        XCTAssertFalse(BeaconDetailRuntime.isUserWithinDestinationGeofence(location(latitude: 47.62, longitude: -122.34)))
    }

    func testAdditionalVisualRuntimeHooksDispatchToConfiguredProvider() {
        let provider = MockVisualRuntimeProviders()
        let expectedPlayerID = UUID()
        provider.playAudioResult = expectedPlayerID
        provider.currentUserLocation = CLLocation(latitude: 47.6205, longitude: -122.3493)
        provider.isOffline = true
        provider.checkServiceConnectionResult = true
        VisualRuntimeProviderRegistry.configure(with: provider)

        _ = VisualRuntimeProviderRegistry.providers.routeGuidanceStateStoreActiveRouteGuidance()
        _ = VisualRuntimeProviderRegistry.providers.guidedTourStateStoreActiveTour()
        _ = VisualRuntimeProviderRegistry.providers.beaconStoreActiveRouteGuidance()
        _ = VisualRuntimeProviderRegistry.providers.visualIsCustomBehaviorActive()
        VisualRuntimeProviderRegistry.providers.visualActivateCustomBehavior(MockBehavior())
        VisualRuntimeProviderRegistry.providers.visualDeactivateCustomBehavior()
        VisualRuntimeProviderRegistry.providers.visualProcessEvent(BehaviorActivatedEvent())
        _ = VisualRuntimeProviderRegistry.providers.visualCurrentUserLocation()
        _ = VisualRuntimeProviderRegistry.providers.visualIsOffline()
        VisualRuntimeProviderRegistry.providers.visualHushEventProcessor(playSound: false)
        _ = VisualRuntimeProviderRegistry.providers.visualSpatialDataContext()
        _ = VisualRuntimeProviderRegistry.providers.visualMotionActivityContext()
        let serviceCheckExpectation = expectation(description: "service check completion")
        VisualRuntimeProviderRegistry.providers.visualCheckSpatialServiceConnection { success in
            XCTAssertTrue(success)
            serviceCheckExpectation.fulfill()
        }

        let url = URL(fileURLWithPath: "/tmp/test-audio.mp3")
        let playerID = VisualRuntimeProviderRegistry.providers.audioFileStorePlay(url)
        if let playerID {
            VisualRuntimeProviderRegistry.providers.audioFileStoreStop(playerID)
        }

        XCTAssertEqual(provider.routeGuidanceLookupCount, 2)
        XCTAssertEqual(provider.guidedTourLookupCount, 1)
        XCTAssertEqual(provider.playedAudioURLs, [url])
        XCTAssertEqual(playerID, expectedPlayerID)
        XCTAssertEqual(provider.stoppedAudioIDs, [expectedPlayerID])
        XCTAssertEqual(provider.activateCustomBehaviorCount, 1)
        XCTAssertEqual(provider.deactivateCustomBehaviorCount, 1)
        XCTAssertEqual(provider.processedEventNames, [BehaviorActivatedEvent().name])
        XCTAssertEqual(provider.hushRequests, [false])
        XCTAssertEqual(provider.checkServiceConnectionCallCount, 1)
        XCTAssertEqual(provider.spatialDataLookupCount, 1)
        XCTAssertEqual(provider.motionActivityLookupCount, 1)
        wait(for: [serviceCheckExpectation], timeout: 1.0)
    }
}
