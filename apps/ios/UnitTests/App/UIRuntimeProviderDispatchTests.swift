//
//  UIRuntimeProviderDispatchTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import AVFoundation
import SSGeo
@testable import Soundscape

@MainActor
final class UIRuntimeProviderDispatchTests: XCTestCase {
    private func location(latitude: Double, longitude: Double) -> SSGeoLocation {
        SSGeoLocation(coordinate: SSGeoCoordinate(latitude: latitude, longitude: longitude))
    }

    private final class MockUIRuntimeProviders: UIRuntimeProviders {
        var initialLocation: SSGeoLocation?
        var geofenceResult = false
        var receivedGeofenceInputs: [SSGeoLocation] = []
        var setRemoteCommandDelegateCallCount = 0
        var tutorialModeValues: [Bool] = []
        var isFirstLaunch = false
        var shouldShowNewFeatures = false
        var newFeatures = NewFeatures()
        var routeGuidanceLookupCount = 0
        var guidedTourLookupCount = 0
        var playAudioResult: AudioPlayerIdentifier?
        var playedAudioURLs: [URL] = []
        var stoppedAudioIDs: [AudioPlayerIdentifier] = []
        var customBehaviorActive = false
        var isGuidedTourActive = false
        var isRouteGuidanceActive = false
        var activateCustomBehaviorCount = 0
        var deactivateCustomBehaviorCount = 0
        var processedEventNames: [String] = []
        var currentUserLocation: CLLocation?
        var coreLocationServicesEnabled = true
        var coreLocationAuthorizationStatus: CoreLocationAuthorizationStatus = .fullAccuracyLocationAuthorized
        var isOffline = false
        var isStreetPreviewing = false
        var isDestinationAudioEnabled = false
        var toggleDestinationAudioCallCount = 0
        var hushRequests: [Bool] = []
        var checkServiceConnectionResult = false
        var checkServiceConnectionCallCount = 0
        var spatialDataLookupCount = 0
        var motionActivityLookupCount = 0
        var geolocationManagerLookupCount = 0
        var audioEngineLookupCount = 0
        var reverseGeocodeLookupCount = 0
        var reverseGeocodeLocations: [CLLocation] = []
        var setDeviceManagerDelegateCallCount = 0
        var devices: [Device] = []
        var addedDeviceIDs: [UUID] = []
        var removedDeviceIDs: [UUID] = []
        var userHeading = Heading(orderedBy: [.user], course: nil, deviceHeading: nil, userHeading: HeadingValue(90.0, nil))
        var bleAuthorizationResult = false
        var bleAuthorizationCallCount = 0
        var audioSession = AVAudioSession.sharedInstance()
        var audioSessionLookupCount = 0

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

        func uiSetRemoteCommandDelegate(_ delegate: RemoteCommandManagerDelegate?) {
            setRemoteCommandDelegateCallCount += 1
        }

        func uiSetDeviceManagerDelegate(_ delegate: DeviceManagerDelegate?) {
            setDeviceManagerDelegateCallCount += 1
        }

        func uiDevices() -> [Device] {
            devices
        }

        func uiAddDevice(_ device: Device) {
            addedDeviceIDs.append(device.id)
        }

        func uiRemoveDevice(_ device: Device) {
            removedDeviceIDs.append(device.id)
        }

        func uiUserHeading() -> Heading {
            userHeading
        }

        func uiBLEAuthorizationStatus(_ completion: @escaping (Bool) -> Void) {
            bleAuthorizationCallCount += 1
            completion(bleAuthorizationResult)
        }

        func uiAudioSession() -> AVAudioSession {
            audioSessionLookupCount += 1
            return audioSession
        }

        func uiSetTutorialMode(_ isEnabled: Bool) {
            tutorialModeValues.append(isEnabled)
        }

        func uiIsFirstLaunch() -> Bool {
            isFirstLaunch
        }

        func uiShouldShowNewFeatures() -> Bool {
            shouldShowNewFeatures
        }

        func uiNewFeatures() -> NewFeatures {
            newFeatures
        }

        func uiIsCustomBehaviorActive() -> Bool {
            customBehaviorActive
        }

        func uiIsActiveBehaviorGuidedTour() -> Bool {
            isGuidedTourActive
        }

        func uiIsActiveBehaviorRouteGuidance() -> Bool {
            isRouteGuidanceActive
        }

        func uiActivateCustomBehavior(_ behavior: Behavior) {
            activateCustomBehaviorCount += 1
        }

        func uiDeactivateCustomBehavior() {
            deactivateCustomBehaviorCount += 1
        }

        func uiProcessEvent(_ event: Event) {
            processedEventNames.append(event.name)
        }

        func uiCurrentUserLocation() -> CLLocation? {
            currentUserLocation
        }

        func uiGeolocationManager() -> GeolocationManagerProtocol? {
            geolocationManagerLookupCount += 1
            return nil
        }

        func uiAudioEngine() -> AudioEngineProtocol? {
            audioEngineLookupCount += 1
            return nil
        }

        func uiReverseGeocode(_ location: CLLocation) -> ReverseGeocoderResult? {
            reverseGeocodeLookupCount += 1
            reverseGeocodeLocations.append(location)
            return nil
        }

        func uiCoreLocationServicesEnabled() -> Bool {
            coreLocationServicesEnabled
        }

        func uiCoreLocationAuthorizationStatus() -> CoreLocationAuthorizationStatus {
            coreLocationAuthorizationStatus
        }

        func uiIsOffline() -> Bool {
            isOffline
        }

        func uiIsStreetPreviewing() -> Bool {
            isStreetPreviewing
        }

        func uiIsDestinationAudioEnabled() -> Bool {
            isDestinationAudioEnabled
        }

        func uiToggleDestinationAudio() {
            toggleDestinationAudioCallCount += 1
        }

        func uiHushEventProcessor(playSound: Bool) {
            hushRequests.append(playSound)
        }

        func uiCheckSpatialServiceConnection(_ completion: @escaping (Bool) -> Void) {
            checkServiceConnectionCallCount += 1
            completion(checkServiceConnectionResult)
        }

        func uiSpatialDataContext() -> SpatialDataProtocol? {
            spatialDataLookupCount += 1
            return nil
        }

        func uiMotionActivityContext() -> MotionActivityProtocol? {
            motionActivityLookupCount += 1
            return nil
        }
    }

    override func tearDown() {
        UIRuntimeProviderRegistry.resetForTesting()
        super.tearDown()
    }

    func testUserLocationStoreRuntimeDispatchesToConfiguredProvider() {
        let provider = MockUIRuntimeProviders()
        let expected = location(latitude: 47.6205, longitude: -122.3493)
        provider.initialLocation = expected
        UIRuntimeProviderRegistry.configure(with: provider)

        XCTAssertEqual(UserLocationStoreRuntime.initialUserLocation(), expected)
    }

    func testBeaconDetailRuntimeDispatchesToConfiguredProvider() {
        let provider = MockUIRuntimeProviders()
        provider.geofenceResult = true
        UIRuntimeProviderRegistry.configure(with: provider)

        let userLocation = location(latitude: 47.6205, longitude: -122.3493)
        XCTAssertTrue(BeaconDetailRuntime.isUserWithinDestinationGeofence(userLocation))
        XCTAssertEqual(provider.receivedGeofenceInputs, [userLocation])
    }

    func testProviderResetClearsInjectedProvider() {
        let provider = MockUIRuntimeProviders()
        provider.initialLocation = location(latitude: 47.61, longitude: -122.33)
        provider.geofenceResult = true
        UIRuntimeProviderRegistry.configure(with: provider)

        XCTAssertNotNil(UserLocationStoreRuntime.initialUserLocation())
        XCTAssertTrue(BeaconDetailRuntime.isUserWithinDestinationGeofence(location(latitude: 47.62, longitude: -122.34)))

        UIRuntimeProviderRegistry.resetForTesting()

        XCTAssertNil(UserLocationStoreRuntime.initialUserLocation())
        XCTAssertFalse(BeaconDetailRuntime.isUserWithinDestinationGeofence(location(latitude: 47.62, longitude: -122.34)))
    }

    func testAdditionalUIRuntimeHooksDispatchToConfiguredProvider() {
        final class MockRemoteCommandDelegate: RemoteCommandManagerDelegate {
            func remoteCommandManager(_ remoteCommandManager: RemoteCommandManager, handle event: RemoteCommand) -> Bool {
                true
            }
        }

        let provider = MockUIRuntimeProviders()
        let expectedPlayerID = UUID()
        provider.playAudioResult = expectedPlayerID
        provider.currentUserLocation = CLLocation(latitude: 47.6205, longitude: -122.3493)
        provider.isFirstLaunch = true
        provider.shouldShowNewFeatures = true
        provider.isGuidedTourActive = true
        provider.isRouteGuidanceActive = true
        provider.coreLocationServicesEnabled = false
        provider.coreLocationAuthorizationStatus = .denied
        provider.isOffline = true
        provider.isStreetPreviewing = true
        provider.isDestinationAudioEnabled = true
        provider.checkServiceConnectionResult = true
        provider.bleAuthorizationResult = true
        let testDevice = HeadphoneMotionManagerWrapper(id: UUID(), name: "Test Headphones")
        provider.devices = [testDevice]
        UIRuntimeProviderRegistry.configure(with: provider)

        UIRuntimeProviderRegistry.providers.uiSetRemoteCommandDelegate(MockRemoteCommandDelegate())
        UIRuntimeProviderRegistry.providers.uiSetDeviceManagerDelegate(nil)
        XCTAssertEqual(UIRuntimeProviderRegistry.providers.uiDevices().count, 1)
        UIRuntimeProviderRegistry.providers.uiAddDevice(testDevice)
        UIRuntimeProviderRegistry.providers.uiRemoveDevice(testDevice)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiUserHeading() === provider.userHeading)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiAudioSession() === provider.audioSession)
        UIRuntimeProviderRegistry.providers.uiSetTutorialMode(true)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsFirstLaunch())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiShouldShowNewFeatures())
        _ = UIRuntimeProviderRegistry.providers.uiNewFeatures()
        _ = UIRuntimeProviderRegistry.providers.routeGuidanceStateStoreActiveRouteGuidance()
        _ = UIRuntimeProviderRegistry.providers.guidedTourStateStoreActiveTour()
        _ = UIRuntimeProviderRegistry.providers.beaconStoreActiveRouteGuidance()
        _ = UIRuntimeProviderRegistry.providers.uiIsCustomBehaviorActive()
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsActiveBehaviorGuidedTour())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsActiveBehaviorRouteGuidance())
        UIRuntimeProviderRegistry.providers.uiActivateCustomBehavior(MockBehavior())
        UIRuntimeProviderRegistry.providers.uiDeactivateCustomBehavior()
        UIRuntimeProviderRegistry.providers.uiProcessEvent(BehaviorActivatedEvent())
        _ = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        _ = UIRuntimeProviderRegistry.providers.uiGeolocationManager()
        _ = UIRuntimeProviderRegistry.providers.uiAudioEngine()
        _ = UIRuntimeProviderRegistry.providers.uiReverseGeocode(CLLocation(latitude: 47.6205, longitude: -122.3493))
        XCTAssertFalse(UIRuntimeProviderRegistry.providers.uiCoreLocationServicesEnabled())
        XCTAssertEqual(UIRuntimeProviderRegistry.providers.uiCoreLocationAuthorizationStatus(), .denied)
        _ = UIRuntimeProviderRegistry.providers.uiIsOffline()
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsStreetPreviewing())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsDestinationAudioEnabled())
        UIRuntimeProviderRegistry.providers.uiToggleDestinationAudio()
        UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false)
        _ = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()
        _ = UIRuntimeProviderRegistry.providers.uiMotionActivityContext()
        let serviceCheckExpectation = expectation(description: "service check completion")
        UIRuntimeProviderRegistry.providers.uiCheckSpatialServiceConnection { success in
            XCTAssertTrue(success)
            serviceCheckExpectation.fulfill()
        }
        let bleAuthorizationExpectation = expectation(description: "ble authorization completion")
        UIRuntimeProviderRegistry.providers.uiBLEAuthorizationStatus { authorized in
            XCTAssertTrue(authorized)
            bleAuthorizationExpectation.fulfill()
        }

        let url = URL(fileURLWithPath: "/tmp/test-audio.mp3")
        let playerID = UIRuntimeProviderRegistry.providers.audioFileStorePlay(url)
        if let playerID {
            UIRuntimeProviderRegistry.providers.audioFileStoreStop(playerID)
        }

        XCTAssertEqual(provider.routeGuidanceLookupCount, 2)
        XCTAssertEqual(provider.guidedTourLookupCount, 1)
        XCTAssertEqual(provider.playedAudioURLs, [url])
        XCTAssertEqual(playerID, expectedPlayerID)
        XCTAssertEqual(provider.stoppedAudioIDs, [expectedPlayerID])
        XCTAssertEqual(provider.setRemoteCommandDelegateCallCount, 1)
        XCTAssertEqual(provider.setDeviceManagerDelegateCallCount, 1)
        XCTAssertEqual(provider.addedDeviceIDs, [testDevice.id])
        XCTAssertEqual(provider.removedDeviceIDs, [testDevice.id])
        XCTAssertEqual(provider.bleAuthorizationCallCount, 1)
        XCTAssertEqual(provider.audioSessionLookupCount, 1)
        XCTAssertEqual(provider.tutorialModeValues, [true])
        XCTAssertEqual(provider.activateCustomBehaviorCount, 1)
        XCTAssertEqual(provider.deactivateCustomBehaviorCount, 1)
        XCTAssertEqual(provider.toggleDestinationAudioCallCount, 1)
        XCTAssertEqual(provider.processedEventNames, [BehaviorActivatedEvent().name])
        XCTAssertEqual(provider.hushRequests, [false])
        XCTAssertEqual(provider.checkServiceConnectionCallCount, 1)
        XCTAssertEqual(provider.spatialDataLookupCount, 1)
        XCTAssertEqual(provider.motionActivityLookupCount, 1)
        XCTAssertEqual(provider.geolocationManagerLookupCount, 1)
        XCTAssertEqual(provider.audioEngineLookupCount, 1)
        XCTAssertEqual(provider.reverseGeocodeLookupCount, 1)
        XCTAssertEqual(provider.reverseGeocodeLocations.count, 1)
        if let reverseGeocodeLocation = provider.reverseGeocodeLocations.first {
            XCTAssertEqual(reverseGeocodeLocation.coordinate.latitude, 47.6205, accuracy: 0.0001)
            XCTAssertEqual(reverseGeocodeLocation.coordinate.longitude, -122.3493, accuracy: 0.0001)
        }
        wait(for: [serviceCheckExpectation, bleAuthorizationExpectation], timeout: 1.0)
    }
}
