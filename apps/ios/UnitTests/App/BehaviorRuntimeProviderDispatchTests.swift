//
//  BehaviorRuntimeProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class BehaviorRuntimeProviderDispatchTests: XCTestCase {
    private final class MockBehaviorRuntimeProviders: BehaviorRuntimeProviders {
        var routeLocation: CLLocation?
        var routeSecondaryRoadsContext: SecondaryRoadsContext = .standard

        var tourLocation: CLLocation?
        var tourSecondaryRoadsContext: SecondaryRoadsContext = .standard
        var removeRegisteredPOIsCount = 0

        func routeGuidanceCurrentUserLocation() -> CLLocation? {
            routeLocation
        }

        func routeGuidanceSecondaryRoadsContext() -> SecondaryRoadsContext {
            routeSecondaryRoadsContext
        }

        func guidedTourCurrentUserLocation() -> CLLocation? {
            tourLocation
        }

        func guidedTourSecondaryRoadsContext() -> SecondaryRoadsContext {
            tourSecondaryRoadsContext
        }

        func guidedTourRemoveRegisteredPOIs() {
            removeRegisteredPOIsCount += 1
        }
    }

    override func tearDown() {
        BehaviorRuntimeProviderRegistry.resetForTesting()
        super.tearDown()
    }

    func testRouteGuidanceRuntimeDispatchesToConfiguredProvider() {
        let provider = MockBehaviorRuntimeProviders()
        let location = CLLocation(latitude: 47.62, longitude: -122.35)
        provider.routeLocation = location
        provider.routeSecondaryRoadsContext = .automotive
        BehaviorRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(RouteGuidanceRuntime.currentUserLocation(), location)
        XCTAssertEqual(RouteGuidanceRuntime.secondaryRoadsContext(), .automotive)
    }

    func testGuidedTourRuntimeDispatchesToConfiguredProvider() {
        let provider = MockBehaviorRuntimeProviders()
        let location = CLLocation(latitude: 47.61, longitude: -122.33)
        provider.tourLocation = location
        provider.tourSecondaryRoadsContext = .strict
        BehaviorRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(GuidedTourRuntime.currentUserLocation(), location)
        XCTAssertEqual(GuidedTourRuntime.secondaryRoadsContext(), .strict)

        GuidedTourRuntime.removeRegisteredPOIs()
        XCTAssertEqual(provider.removeRegisteredPOIsCount, 1)
    }

    func testProviderResetClearsInjectedProvider() {
        let provider = MockBehaviorRuntimeProviders()
        provider.routeLocation = CLLocation(latitude: 47.63, longitude: -122.36)
        provider.routeSecondaryRoadsContext = .automotive
        provider.tourLocation = CLLocation(latitude: 47.64, longitude: -122.37)
        provider.tourSecondaryRoadsContext = .strict
        BehaviorRuntimeProviderRegistry.configure(with: provider)

        XCTAssertNotNil(RouteGuidanceRuntime.currentUserLocation())
        XCTAssertEqual(RouteGuidanceRuntime.secondaryRoadsContext(), .automotive)
        XCTAssertNotNil(GuidedTourRuntime.currentUserLocation())
        XCTAssertEqual(GuidedTourRuntime.secondaryRoadsContext(), .strict)

        BehaviorRuntimeProviderRegistry.resetForTesting()

        XCTAssertNil(RouteGuidanceRuntime.currentUserLocation())
        XCTAssertEqual(RouteGuidanceRuntime.secondaryRoadsContext(), .standard)
        XCTAssertNil(GuidedTourRuntime.currentUserLocation())
        XCTAssertEqual(GuidedTourRuntime.secondaryRoadsContext(), .standard)
    }
}
