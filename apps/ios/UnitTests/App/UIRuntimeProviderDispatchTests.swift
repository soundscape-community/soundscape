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

    private final class MockAuthorizationProvider: AsyncAuthorizationProvider {
        weak var authorizationDelegate: AsyncAuthorizationProviderDelegate?
        var authorizationStatus: AuthorizationStatus = .notDetermined

        func requestAuthorization() {}
    }

    private final class MockUIRuntimeProviders: UIRuntimeProviders {
        var initialLocation: SSGeoLocation?
        var geofenceResult = false
        var receivedGeofenceInputs: [SSGeoLocation] = []
        var setRemoteCommandDelegateCallCount = 0
        var tutorialModeValues: [Bool] = []
        var isFirstLaunch = false
        var telemetryHelperLookupCount = 0
        var startAppFromFirstLaunchValues: [Bool] = []
        var shouldShowNewFeatures = false
        var newFeatures = NewFeatures()
        var routeGuidanceLookupCount = 0
        var activeRouteGuidanceLookupCount = 0
        var guidedTourLookupCount = 0
        var isApplicationInNormalState = true
        var goToSleepCallCount = 0
        var snoozeCallCount = 0
        var wakeUpCallCount = 0
        var activeBehaviorID = UUID()
        var activeBehaviorIDLookupCount = 0
        var toggleAudioResult = false
        var toggleAudioCallCount = 0
        var playAudioResult: AudioPlayerIdentifier?
        var playedAudioURLs: [URL] = []
        var stoppedAudioIDs: [AudioPlayerIdentifier] = []
        var customBehaviorActive = false
        var isSoundscapeBehaviorActive = false
        var isGuidedTourActive = false
        var isRouteGuidanceActive = false
        var activateCustomBehaviorCount = 0
        var deactivateCustomBehaviorCount = 0
        var processedEventNames: [String] = []
        var currentUserLocation: CLLocation?
        var currentPreviewDecisionPoint: IntersectionDecisionPoint?
        var currentPreviewDecisionPointLookupCount = 0
        var coreLocationServicesEnabled = true
        var coreLocationAuthorizationStatus: CoreLocationAuthorizationStatus = .fullAccuracyLocationAuthorized
        var locationAuthorizationProvider: AsyncAuthorizationProvider?
        var motionAuthorizationProvider: AsyncAuthorizationProvider?
        var locationAuthorizationProviderLookupCount = 0
        var motionAuthorizationProviderLookupCount = 0
        var isOffline = false
        var calloutHistoryLookupCount = 0
        var calloutHistoryCallouts: [CalloutProtocol] = []
        var isStreetPreviewing = false
        var isDestinationSet = false
        var isDestinationAudioEnabled = false
        var toggleDestinationAudioCallCount = 0
        var toggleDestinationAudioAutomaticInputs: [Bool] = []
        var toggleDestinationAudioAutomaticResult = false
        var hushRequests: [Bool] = []
        var hushRequestsWithBeacon: [(playSound: Bool, hushBeacon: Bool)] = []
        var isSimulatingGPX = false
        var toggleGPXSimulationStateResult: Bool?
        var toggleGPXSimulationStateCallCount = 0
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
        var presentationHeadingLookupCount = 0
        var userHeading = Heading(orderedBy: [.user], course: nil, deviceHeading: nil, userHeading: HeadingValue(90.0, nil))
        var setExperimentDelegateCallCount = 0
        var setExperimentDelegateToNilCount = 0
        var initializeExperimentManagerCallCount = 0
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

        func uiSetExperimentManagerDelegate(_ delegate: ExperimentManagerDelegate?) {
            setExperimentDelegateCallCount += 1
            if delegate == nil {
                setExperimentDelegateToNilCount += 1
            }
        }

        func uiInitializeExperimentManager() {
            initializeExperimentManagerCallCount += 1
        }

        func uiIsApplicationInNormalState() -> Bool {
            isApplicationInNormalState
        }

        func uiGoToSleep() {
            goToSleepCallCount += 1
        }

        func uiSnooze() {
            snoozeCallCount += 1
        }

        func uiWakeUp() {
            wakeUpCallCount += 1
        }

        func uiActiveBehaviorID() -> UUID {
            activeBehaviorIDLookupCount += 1
            return activeBehaviorID
        }

        func uiActiveRouteGuidance() -> RouteGuidance? {
            activeRouteGuidanceLookupCount += 1
            return nil
        }

        func uiToggleAudio() -> Bool {
            toggleAudioCallCount += 1
            return toggleAudioResult
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

        func uiPresentationHeading() -> Heading {
            presentationHeadingLookupCount += 1
            return userHeading
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

        func uiTelemetryHelper() -> TelemetryHelper? {
            telemetryHelperLookupCount += 1
            return nil
        }

        func uiStartApp(fromFirstLaunch: Bool) {
            startAppFromFirstLaunchValues.append(fromFirstLaunch)
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

        func uiIsActiveBehaviorSoundscape() -> Bool {
            isSoundscapeBehaviorActive
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

        func uiCurrentPreviewDecisionPoint() -> IntersectionDecisionPoint? {
            currentPreviewDecisionPointLookupCount += 1
            return currentPreviewDecisionPoint
        }

        func uiCalloutHistoryCallouts() -> [CalloutProtocol] {
            calloutHistoryLookupCount += 1
            return calloutHistoryCallouts
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

        func uiLocationAuthorizationProvider() -> AsyncAuthorizationProvider? {
            locationAuthorizationProviderLookupCount += 1
            return locationAuthorizationProvider
        }

        func uiMotionAuthorizationProvider() -> AsyncAuthorizationProvider? {
            motionAuthorizationProviderLookupCount += 1
            return motionAuthorizationProvider
        }

        func uiIsOffline() -> Bool {
            isOffline
        }

        func uiIsStreetPreviewing() -> Bool {
            isStreetPreviewing
        }

        func uiIsDestinationSet() -> Bool {
            isDestinationSet
        }

        func uiIsDestinationAudioEnabled() -> Bool {
            isDestinationAudioEnabled
        }

        func uiToggleDestinationAudio() {
            toggleDestinationAudioCallCount += 1
        }

        func uiToggleDestinationAudio(automatic: Bool) -> Bool {
            toggleDestinationAudioAutomaticInputs.append(automatic)
            return toggleDestinationAudioAutomaticResult
        }

        func uiHushEventProcessor(playSound: Bool) {
            hushRequests.append(playSound)
        }

        func uiHushEventProcessor(playSound: Bool, hushBeacon: Bool) {
            hushRequestsWithBeacon.append((playSound, hushBeacon))
        }

        func uiIsSimulatingGPX() -> Bool {
            isSimulatingGPX
        }

        func uiToggleGPXSimulationState() -> Bool? {
            toggleGPXSimulationStateCallCount += 1
            return toggleGPXSimulationStateResult
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
        provider.isSoundscapeBehaviorActive = true
        provider.isGuidedTourActive = true
        provider.isRouteGuidanceActive = true
        provider.isDestinationSet = true
        provider.coreLocationServicesEnabled = false
        provider.coreLocationAuthorizationStatus = .denied
        provider.isOffline = true
        provider.isStreetPreviewing = true
        provider.isDestinationAudioEnabled = true
        provider.isApplicationInNormalState = false
        provider.toggleAudioResult = true
        provider.toggleDestinationAudioAutomaticResult = true
        provider.isSimulatingGPX = true
        provider.toggleGPXSimulationStateResult = false
        provider.checkServiceConnectionResult = true
        provider.bleAuthorizationResult = true
        let locationAuthProvider = MockAuthorizationProvider()
        let motionAuthProvider = MockAuthorizationProvider()
        provider.locationAuthorizationProvider = locationAuthProvider
        provider.motionAuthorizationProvider = motionAuthProvider
        let testDevice = HeadphoneMotionManagerWrapper(id: UUID(), name: "Test Headphones")
        provider.devices = [testDevice]
        UIRuntimeProviderRegistry.configure(with: provider)

        UIRuntimeProviderRegistry.providers.uiSetRemoteCommandDelegate(MockRemoteCommandDelegate())
        UIRuntimeProviderRegistry.providers.uiSetDeviceManagerDelegate(nil)
        UIRuntimeProviderRegistry.providers.uiSetExperimentManagerDelegate(nil)
        UIRuntimeProviderRegistry.providers.uiInitializeExperimentManager()
        XCTAssertFalse(UIRuntimeProviderRegistry.providers.uiIsApplicationInNormalState())
        UIRuntimeProviderRegistry.providers.uiGoToSleep()
        UIRuntimeProviderRegistry.providers.uiSnooze()
        UIRuntimeProviderRegistry.providers.uiWakeUp()
        XCTAssertEqual(UIRuntimeProviderRegistry.providers.uiActiveBehaviorID(), provider.activeBehaviorID)
        _ = UIRuntimeProviderRegistry.providers.uiActiveRouteGuidance()
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiToggleAudio())
        XCTAssertEqual(UIRuntimeProviderRegistry.providers.uiDevices().count, 1)
        UIRuntimeProviderRegistry.providers.uiAddDevice(testDevice)
        UIRuntimeProviderRegistry.providers.uiRemoveDevice(testDevice)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiPresentationHeading() === provider.userHeading)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiUserHeading() === provider.userHeading)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiAudioSession() === provider.audioSession)
        UIRuntimeProviderRegistry.providers.uiSetTutorialMode(true)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsFirstLaunch())
        XCTAssertNil(UIRuntimeProviderRegistry.providers.uiTelemetryHelper())
        UIRuntimeProviderRegistry.providers.uiStartApp(fromFirstLaunch: true)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiShouldShowNewFeatures())
        _ = UIRuntimeProviderRegistry.providers.uiNewFeatures()
        _ = UIRuntimeProviderRegistry.providers.routeGuidanceStateStoreActiveRouteGuidance()
        _ = UIRuntimeProviderRegistry.providers.guidedTourStateStoreActiveTour()
        _ = UIRuntimeProviderRegistry.providers.beaconStoreActiveRouteGuidance()
        _ = UIRuntimeProviderRegistry.providers.uiIsCustomBehaviorActive()
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsActiveBehaviorSoundscape())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsActiveBehaviorGuidedTour())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsActiveBehaviorRouteGuidance())
        UIRuntimeProviderRegistry.providers.uiActivateCustomBehavior(MockBehavior())
        UIRuntimeProviderRegistry.providers.uiDeactivateCustomBehavior()
        UIRuntimeProviderRegistry.providers.uiProcessEvent(BehaviorActivatedEvent())
        _ = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        XCTAssertNil(UIRuntimeProviderRegistry.providers.uiCurrentPreviewDecisionPoint())
        _ = UIRuntimeProviderRegistry.providers.uiCalloutHistoryCallouts()
        _ = UIRuntimeProviderRegistry.providers.uiGeolocationManager()
        _ = UIRuntimeProviderRegistry.providers.uiAudioEngine()
        _ = UIRuntimeProviderRegistry.providers.uiReverseGeocode(CLLocation(latitude: 47.6205, longitude: -122.3493))
        XCTAssertFalse(UIRuntimeProviderRegistry.providers.uiCoreLocationServicesEnabled())
        XCTAssertEqual(UIRuntimeProviderRegistry.providers.uiCoreLocationAuthorizationStatus(), .denied)
        let observedLocationAuthProvider = UIRuntimeProviderRegistry.providers.uiLocationAuthorizationProvider() as? MockAuthorizationProvider
        let observedMotionAuthProvider = UIRuntimeProviderRegistry.providers.uiMotionAuthorizationProvider() as? MockAuthorizationProvider
        XCTAssertTrue(observedLocationAuthProvider === locationAuthProvider)
        XCTAssertTrue(observedMotionAuthProvider === motionAuthProvider)
        _ = UIRuntimeProviderRegistry.providers.uiIsOffline()
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsStreetPreviewing())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsDestinationSet())
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsDestinationAudioEnabled())
        UIRuntimeProviderRegistry.providers.uiToggleDestinationAudio()
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiToggleDestinationAudio(automatic: false))
        UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false)
        UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false, hushBeacon: false)
        XCTAssertTrue(UIRuntimeProviderRegistry.providers.uiIsSimulatingGPX())
        XCTAssertEqual(UIRuntimeProviderRegistry.providers.uiToggleGPXSimulationState(), false)
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
        XCTAssertEqual(provider.setExperimentDelegateCallCount, 1)
        XCTAssertEqual(provider.setExperimentDelegateToNilCount, 1)
        XCTAssertEqual(provider.initializeExperimentManagerCallCount, 1)
        XCTAssertEqual(provider.goToSleepCallCount, 1)
        XCTAssertEqual(provider.snoozeCallCount, 1)
        XCTAssertEqual(provider.wakeUpCallCount, 1)
        XCTAssertEqual(provider.activeBehaviorIDLookupCount, 1)
        XCTAssertEqual(provider.activeRouteGuidanceLookupCount, 1)
        XCTAssertEqual(provider.toggleAudioCallCount, 1)
        XCTAssertEqual(provider.addedDeviceIDs, [testDevice.id])
        XCTAssertEqual(provider.removedDeviceIDs, [testDevice.id])
        XCTAssertEqual(provider.presentationHeadingLookupCount, 1)
        XCTAssertEqual(provider.bleAuthorizationCallCount, 1)
        XCTAssertEqual(provider.audioSessionLookupCount, 1)
        XCTAssertEqual(provider.telemetryHelperLookupCount, 1)
        XCTAssertEqual(provider.startAppFromFirstLaunchValues, [true])
        XCTAssertEqual(provider.tutorialModeValues, [true])
        XCTAssertEqual(provider.activateCustomBehaviorCount, 1)
        XCTAssertEqual(provider.deactivateCustomBehaviorCount, 1)
        XCTAssertEqual(provider.toggleDestinationAudioCallCount, 1)
        XCTAssertEqual(provider.toggleDestinationAudioAutomaticInputs, [false])
        XCTAssertEqual(provider.calloutHistoryLookupCount, 1)
        XCTAssertEqual(provider.currentPreviewDecisionPointLookupCount, 1)
        XCTAssertEqual(provider.processedEventNames, [BehaviorActivatedEvent().name])
        XCTAssertEqual(provider.hushRequests, [false])
        XCTAssertEqual(provider.hushRequestsWithBeacon.count, 1)
        XCTAssertEqual(provider.hushRequestsWithBeacon.first?.playSound, false)
        XCTAssertEqual(provider.hushRequestsWithBeacon.first?.hushBeacon, false)
        XCTAssertEqual(provider.toggleGPXSimulationStateCallCount, 1)
        XCTAssertEqual(provider.checkServiceConnectionCallCount, 1)
        XCTAssertEqual(provider.spatialDataLookupCount, 1)
        XCTAssertEqual(provider.motionActivityLookupCount, 1)
        XCTAssertEqual(provider.geolocationManagerLookupCount, 1)
        XCTAssertEqual(provider.audioEngineLookupCount, 1)
        XCTAssertEqual(provider.reverseGeocodeLookupCount, 1)
        XCTAssertEqual(provider.locationAuthorizationProviderLookupCount, 1)
        XCTAssertEqual(provider.motionAuthorizationProviderLookupCount, 1)
        XCTAssertEqual(provider.reverseGeocodeLocations.count, 1)
        if let reverseGeocodeLocation = provider.reverseGeocodeLocations.first {
            XCTAssertEqual(reverseGeocodeLocation.coordinate.latitude, 47.6205, accuracy: 0.0001)
            XCTAssertEqual(reverseGeocodeLocation.coordinate.longitude, -122.3493, accuracy: 0.0001)
        }
        wait(for: [serviceCheckExpectation, bleAuthorizationExpectation], timeout: 1.0)
    }
}
