//
//  VisualRuntimeProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
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

        func userLocationStoreInitialUserLocation() -> SSGeoLocation? {
            initialLocation
        }

        func beaconDetailIsUserWithinDestinationGeofence(_ userLocation: SSGeoLocation) -> Bool {
            receivedGeofenceInputs.append(userLocation)
            return geofenceResult
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
}
