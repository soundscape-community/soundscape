//
//  DestinationManagerTest.swift
//  UnitTests
//
//  Created by Kai on 10/3/23.
//  Copyright © 2023 Microsoft. All rights reserved.
//  Copyright (c) Soundscape Community Contributors.
//

import XCTest
import CoreLocation
@testable import Soundscape

final class DestinationManagerTest: XCTestCase {
    
    let basic_audio_engine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true)
    let empty_heading = Heading(orderedBy: [], course: nil, deviceHeading: nil, userHeading: nil, geolocationManager: nil)
    /// The intersection of Sage Ave. and Burdett Ave. in Troy, NY
    let sage_burdett_coord = CLLocation(latitude: 42.7290570, longitude: -73.6726370)
    /// The 'front' of Barton Hall at RPI in Troy, NY
    let barton_front_coord = CLLocation(latitude: 42.7294341, longitude: -73.6740136)
    /// The ends of the bridge at the center of RPI, crossing 15th Street, Troy, NY
    let rpi_bridge_east = CLLocation(latitude: 42.7292999, longitude: -73.6774054)
    let rpi_bridge_west = CLLocation(latitude: 42.7293598, longitude: -73.6778063)
    
    class TestSearchProvider: POISearchProviderProtocol {
        var providerName: String = "testsearchprovider123"
        
        func search(byKey: String) -> Soundscape.POI? {
            return nil
        }
        
        func objects(predicate: NSPredicate) -> [Soundscape.POI] {
            return []
        }
    }
    
    let search_provider = TestSearchProvider()
    
    override func setUp() {
        // We have to provide our own POI search provider (turns locations into POIs)
        SpatialDataCache.register(provider: search_provider)
    }

    override func tearDownWithError() throws {
        // Clean up our POI search provider
        SpatialDataCache.removeAllProviders()
    }
    
    func test_empty_init() throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        // nope? XCTAssertFalse(dm.isDestinationSet)
        XCTAssertFalse(dm.isAudioEnabled)
        XCTAssertFalse(dm.isBeaconInBounds)
        XCTAssertNil(dm.beaconPlayerId)
    }
    
    func testBasicDestination() throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        XCTAssertFalse(dm.isDestinationSet)
        let ref_entity = try dm.setDestination(location: sage_burdett_coord, address: nil, enableAudio: false, userLocation: barton_front_coord)
        XCTAssertFalse(dm.isUserWithinGeofence(barton_front_coord)) // we are not at the destination
        XCTAssertTrue(dm.isDestinationSet)
        XCTAssertTrue(dm.isDestination(key: ref_entity))
        XCTAssertFalse(dm.isDestination(key: "asdf (:"))
        XCTAssertFalse(dm.isDestination(key: ref_entity + "AA"))
        
        // clear destination
        
        try dm.clearDestination()
        XCTAssertFalse(dm.isDestinationSet)
        XCTAssertFalse(dm.isAudioEnabled)
        // clearing should delete our temporary destination location, meaning this should error:
        XCTAssertThrowsError(try dm.setDestination(referenceID: ref_entity, enableAudio: false, userLocation: nil, logContext: nil))
    }
    
    /// geofence is within `EnterImmediateVicinityDistance` and `LeaveImmediateVicinityDistance` of the destination
    func testDestinationInGeoFence() throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        _ = try dm.setDestination(location: rpi_bridge_east, address: nil, enableAudio: true, userLocation: rpi_bridge_east)
        XCTAssertFalse(dm.isAudioEnabled) // since we are already at the destination, audio should be disabled
        XCTAssertTrue(dm.isUserWithinGeofence(rpi_bridge_east)) // we are at the destination
        XCTAssertFalse(dm.isUserWithinGeofence(rpi_bridge_west)) // if we were across the bridge we would not be
        // (how close is the other side of the bridge? should it be?)
        XCTAssertFalse(dm.isUserWithinGeofence(barton_front_coord)) // definitely not from barton hall
        
        // clear destination
        
        try dm.clearDestination()
        XCTAssertFalse(dm.isDestinationSet)
        XCTAssertFalse(dm.isAudioEnabled)
        XCTAssertFalse(dm.isUserWithinGeofence(rpi_bridge_east)) // no longer in geofence as it is gone
        XCTAssertFalse(dm.isUserWithinGeofence(rpi_bridge_west)) // and still across the bridge isn't either
    }
    
    

}

final class SettingsContextTest: XCTestCase {
    private let arrivalKey = "GDAEnterImmediateVicinityDistance"
    private let leaveKey = "GDALeaveImmediateVicinityDistance"
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }

        suiteNames.removeAll()
        super.tearDown()
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "SettingsContextTest.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testDelayedStartDefaultsOffAndPersists() {
        let defaults = makeUserDefaults()
        let settings = SettingsContext(userDefaults: defaults)
        XCTAssertFalse(settings.delayedStartEnabled)
        settings.delayedStartEnabled = true
        XCTAssertTrue(SettingsContext(userDefaults: defaults).delayedStartEnabled)
        settings.delayedStartEnabled = false
        XCTAssertFalse(SettingsContext(userDefaults: defaults).delayedStartEnabled)
    }

    func testFreshStoreUsesDefaultArrivalDistanceAndHysteresis() {
        let defaults = makeUserDefaults()
        let settings = SettingsContext(userDefaults: defaults)

        XCTAssertEqual(settings.enterImmediateVicinityDistance, 10.0)
        XCTAssertEqual(settings.leaveImmediateVicinityDistance, 25.0)
        XCTAssertEqual(defaults.double(forKey: arrivalKey), 10.0)
        XCTAssertEqual(defaults.double(forKey: leaveKey), 25.0)
    }

    func testValidPersistedArrivalDistancesSurviveInitialization() {
        for value in [1.0, 25.0, 50.0] {
            let defaults = makeUserDefaults()
            defaults.set(value, forKey: arrivalKey)

            let settings = SettingsContext(userDefaults: defaults)

            XCTAssertEqual(settings.enterImmediateVicinityDistance, value)
            XCTAssertEqual(settings.leaveImmediateVicinityDistance, value + 15.0)
        }
    }

    func testPersistedArrivalDistanceIsMigratedAndClamped() {
        for (persisted, expected) in [(0.0, 1.0), (-10.0, 1.0), (75.0, 50.0)] {
            let defaults = makeUserDefaults()
            defaults.set(persisted, forKey: arrivalKey)

            let settings = SettingsContext(userDefaults: defaults)

            XCTAssertEqual(settings.enterImmediateVicinityDistance, expected)
            XCTAssertEqual(defaults.double(forKey: arrivalKey), expected)
            XCTAssertEqual(defaults.double(forKey: leaveKey), expected + 15.0)
        }
    }

    func testArrivalDistanceReadsFromCacheAndSetterPersistsBothDistances() {
        let defaults = makeUserDefaults()
        let settings = SettingsContext(userDefaults: defaults)

        defaults.set(42.0, forKey: arrivalKey)
        defaults.set(57.0, forKey: leaveKey)
        XCTAssertEqual(settings.enterImmediateVicinityDistance, 10.0)
        XCTAssertEqual(settings.leaveImmediateVicinityDistance, 25.0)

        settings.enterImmediateVicinityDistance = 30.0
        XCTAssertEqual(settings.enterImmediateVicinityDistance, 30.0)
        XCTAssertEqual(settings.leaveImmediateVicinityDistance, 45.0)
        XCTAssertEqual(defaults.double(forKey: arrivalKey), 30.0)
        XCTAssertEqual(defaults.double(forKey: leaveKey), 45.0)

        settings.leaveImmediateVicinityDistance = 35.0
        XCTAssertEqual(settings.enterImmediateVicinityDistance, 20.0)
        XCTAssertEqual(settings.leaveImmediateVicinityDistance, 35.0)
        XCTAssertEqual(defaults.double(forKey: arrivalKey), 20.0)
        XCTAssertEqual(defaults.double(forKey: leaveKey), 35.0)
    }

    func testArrivalDistanceBoundaryIsInclusive() {
        XCTAssertFalse(SettingsContext.isWithinArrivalDistance(10.01, arrivalDistance: 10.0))
        XCTAssertTrue(SettingsContext.isWithinArrivalDistance(10.0, arrivalDistance: 10.0))
        XCTAssertTrue(SettingsContext.isWithinArrivalDistance(9.99, arrivalDistance: 10.0))
    }

    func testArrivalDistanceControlConstants() {
        XCTAssertEqual(SettingsContext.ArrivalDistance.minimum, 1.0)
        XCTAssertEqual(SettingsContext.ArrivalDistance.defaultValue, 10.0)
        XCTAssertEqual(SettingsContext.ArrivalDistance.maximum, 50.0)
        XCTAssertEqual(SettingsContext.ArrivalDistance.step, 1.0)
        XCTAssertEqual(SettingsContext.ArrivalDistance.exitHysteresis, 15.0)
    }

    func testArrivalDistanceExactEntryFormattingAndPersistence() {
        XCTAssertEqual(ArrivalDistanceValue.displayNumber(10, locale: Locale(identifier: "en_GB")), "10")
        XCTAssertEqual(ArrivalDistanceValue.displayNumber(10.5, locale: Locale(identifier: "en_GB")), "10.5")
        XCTAssertEqual(ArrivalDistanceValue.displayNumber(10.25, locale: Locale(identifier: "en_GB")), "10.25")
        XCTAssertEqual(ArrivalDistanceValue.displayNumber(10.25, locale: Locale(identifier: "fr_FR")), "10,25")

        let defaults = makeUserDefaults()
        let settings = SettingsContext(userDefaults: defaults)
        settings.enterImmediateVicinityDistance = 10.25
        XCTAssertEqual(settings.enterImmediateVicinityDistance, 10.25)
        XCTAssertEqual(settings.leaveImmediateVicinityDistance, 25.25)
        XCTAssertEqual(defaults.double(forKey: arrivalKey), 10.25)
    }

    func testArrivalDistanceExactEntryAcceptsLocalizedHundredths() {
        let enGB = Locale(identifier: "en_GB")
        let frFR = Locale(identifier: "fr_FR")
        let parse: (String, Locale) -> Double? = {
            ArrivalDistanceValue.parse($0, locale: $1, minValue: 1, maxValue: 50)
        }

        XCTAssertEqual(parse("1", enGB), 1)
        XCTAssertEqual(parse("50.00", enGB), 50)
        XCTAssertEqual(parse("10.5", enGB), 10.5)
        XCTAssertEqual(parse("10.25", enGB), 10.25)
        XCTAssertEqual(parse(" 10,25 ", frFR), 10.25)
        XCTAssertEqual(parse("10.25", frFR), 10.25)
        XCTAssertEqual(parse("10,25", enGB), 10.25)
    }

    func testArrivalDistanceExactEntryRejectsInvalidValues() {
        let locale = Locale(identifier: "en_GB")
        for input in ["", " ", ".", "1.", "abc", "0.99", "50.01", "1.234", "1,2,3", "1 2", "-1", "NaN"] {
            XCTAssertNil(ArrivalDistanceValue.parse(input, locale: locale, minValue: 1, maxValue: 50), input)
        }
    }
}

final class DelayedBeaconStartTest: XCTestCase {
    func testFixedInclusiveThreshold() {
        var state = DelayedBeaconStart.armed
        XCTAssertFalse(state.shouldActivate(distance: 300.01, hasArrived: false))
        XCTAssertTrue(state.shouldActivate(distance: 300, hasArrived: false))
        XCTAssertTrue(state.shouldActivate(distance: 299.99, hasArrived: false))
    }

    func testManualMuteInsideRequiresExitAndReentry() {
        for distance in [100.0, 300.0] {
            var state = DelayedBeaconStart.afterManualMute(enabled: true, distance: distance)
            for _ in 0..<3 {
                XCTAssertFalse(state.shouldActivate(distance: 250, hasArrived: false))
            }
            XCTAssertFalse(state.shouldActivate(distance: 300, hasArrived: false))
            XCTAssertFalse(state.shouldActivate(distance: 301, hasArrived: false))
            XCTAssertEqual(state, .armed)
            XCTAssertTrue(state.shouldActivate(distance: 300, hasArrived: false))
        }
    }

    func testManualMuteOutsideRearms() {
        var state = DelayedBeaconStart.afterManualMute(enabled: true, distance: 400)
        XCTAssertEqual(state, .armed)
        XCTAssertTrue(state.shouldActivate(distance: 200, hasArrived: false))
    }

    func testManualMuteWithoutLocationRequiresOutsideFix() {
        var state = DelayedBeaconStart.afterManualMute(enabled: true, distance: nil)
        XCTAssertFalse(state.shouldActivate(distance: 100, hasArrived: false))
        XCTAssertFalse(state.shouldActivate(distance: 400, hasArrived: false))
        XCTAssertTrue(state.shouldActivate(distance: 100, hasArrived: false))
    }

    func testArrivalCancelsEvenWhenJumpingAcrossActivationRadius() {
        for initial in [DelayedBeaconStart.armed, .waitingForExit] {
            var state = initial
            XCTAssertFalse(state.shouldActivate(distance: 5, hasArrived: true))
            XCTAssertEqual(state, .inactive)
            XCTAssertFalse(state.shouldActivate(distance: 400, hasArrived: false))
            XCTAssertFalse(state.shouldActivate(distance: 200, hasArrived: false))
        }
    }

    func testDisabledAndCompletedStartsStayInactive() {
        var state = DelayedBeaconStart.afterManualMute(enabled: false, distance: 400)
        XCTAssertEqual(state, .inactive)
        for distance in [400.0, 300.0, 100.0, 5.0] {
            XCTAssertFalse(state.shouldActivate(distance: distance, hasArrived: false))
        }
    }
}

final class DelayedStartDestinationManagerTest: XCTestCase {
    private class RecordingAudioEngine: AudioEngine {
        var starts = 0
        override func play<T: DynamicSound>(_ sound: T, heading: Heading? = nil) -> AudioPlayerIdentifier? {
            starts += 1
            return UUID()
        }
        override func stop(_ id: AudioPlayerIdentifier) { }
        override func finish(dynamicPlayerId: AudioPlayerIdentifier) { }
    }

    private var engine: RecordingAudioEngine!
    private var manager: DestinationManager!
    private var behaviorOverride: Behavior?
    private var savedSetting = false
    private var savedArrivalDistance = 10.0
    private var savedBeacon = ""
    private let destination = CLLocation(latitude: 0, longitude: 0)
    private func location(_ meters: Double) -> CLLocation {
        CLLocation(destination.coordinate.destination(distance: meters, bearing: 0))
    }

    override func setUpWithError() throws {
        savedSetting = SettingsContext.shared.delayedStartEnabled
        savedArrivalDistance = SettingsContext.shared.enterImmediateVicinityDistance
        savedBeacon = SettingsContext.shared.selectedBeacon
        SettingsContext.shared.delayedStartEnabled = true
        SettingsContext.shared.enterImmediateVicinityDistance = 10
        SettingsContext.shared.selectedBeacon = ClassicBeacon.description
        engine = RecordingAudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true)
        manager = DestinationManager(audioEngine: engine, collectionHeading: Heading(
            orderedBy: [], course: nil, deviceHeading: nil, userHeading: nil, geolocationManager: nil),
            activeBehavior: { [weak self] in self?.behaviorOverride ?? BehaviorBase() })
        try manager.clearDestination()
    }

    override func tearDownWithError() throws {
        try manager.clearDestination()
        manager = nil
        engine = nil
        behaviorOverride = nil
        SettingsContext.shared.delayedStartEnabled = savedSetting
        SettingsContext.shared.enterImmediateVicinityDistance = savedArrivalDistance
        SettingsContext.shared.selectedBeacon = savedBeacon
    }

    private func setBeacon(distance: Double?, enableAudio: Bool = true) throws {
        try manager.setDestination(location: destination, address: nil, enableAudio: enableAudio,
                                   userLocation: distance.map(location))
    }

    func testFarBeaconStaysSetAndAutomaticallyStartsOnce() throws {
        try setBeacon(distance: 500)
        XCTAssertTrue(manager.isDestinationSet)
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertFalse(manager.toggleDestinationAudio(automatic: true, forceMelody: true))
        manager.updateDelayedStart(for: location(400))
        XCTAssertEqual(engine.starts, 0)
        manager.updateDelayedStart(for: location(200))
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        manager.updateDelayedStart(for: location(500))
        manager.updateDelayedStart(for: location(200))
        XCTAssertEqual(engine.starts, 1)
    }

    func testManualUnmuteOverridesAndManualMuteRearms() throws {
        try setBeacon(distance: 500)
        XCTAssertTrue(manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(500)))
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        manager.updateDelayedStart(for: location(400))
        XCTAssertEqual(engine.starts, 1)
        XCTAssertTrue(manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(400)))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .armed)
        manager.updateDelayedStart(for: location(200))
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(engine.starts, 2)
    }

    func testManualMuteInsideDoesNotImmediatelyUnmute() throws {
        try setBeacon(distance: 200)
        XCTAssertTrue(manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(200)))
        for _ in 0..<3 { manager.updateDelayedStart(for: location(200)) }
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(engine.starts, 1)
        manager.updateDelayedStart(for: location(400))
        manager.updateDelayedStart(for: location(200))
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(engine.starts, 2)
    }

    func testAutomaticMuteDoesNotRearm() throws {
        try setBeacon(distance: 200)
        XCTAssertTrue(manager.toggleDestinationAudio(false, automatic: true, forceMelody: false, userLocation: location(200)))
        manager.updateDelayedStart(for: location(400))
        manager.updateDelayedStart(for: location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
    }

    func testNearBeaconStartsImmediatelyAndOffRetainsExistingBehavior() throws {
        try setBeacon(distance: 200)
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        SettingsContext.shared.delayedStartEnabled = false
        try setBeacon(distance: 500)
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(engine.starts, 2)
    }

    func testNoLocationWaitsAndExplicitlyDisabledAudioDoesNotArm() throws {
        try setBeacon(distance: nil)
        XCTAssertFalse(manager.isAudioEnabled)
        manager.updateDelayedStart(for: location(200))
        XCTAssertTrue(manager.isAudioEnabled)
        try setBeacon(distance: 500, enableAudio: false)
        manager.updateDelayedStart(for: location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
    }

    func testArrivalWinsAndLeavingDoesNotRestart() throws {
        for arrivalDistance in [1.0, 10.0, 50.0] {
            SettingsContext.shared.enterImmediateVicinityDistance = arrivalDistance
            try setBeacon(distance: 500)
            manager.updateDelayedStart(for: location(arrivalDistance / 2))
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertEqual(manager.delayedStartState, .inactive)
            manager.updateDelayedStart(for: location(200))
            XCTAssertFalse(manager.isAudioEnabled)
            try setBeacon(distance: arrivalDistance / 2)
            XCTAssertFalse(manager.isAudioEnabled)
        }
    }

    func testLocationNotificationWorksWhenBehaviorOwnsBeaconCallouts() throws {
        behaviorOverride = BehaviorBase(blockedAutoGenerators: [BeaconCalloutGenerator.self])
        try setBeacon(distance: 500)
        NotificationCenter.default.post(name: .locationUpdated, object: nil,
                                        userInfo: [SpatialDataContext.Keys.location: location(200)])
        XCTAssertTrue(manager.isAudioEnabled)
    }

    func testDistanceCalloutsContinueWhileDelayedAudioIsMuted() throws {
        try setBeacon(distance: 500)
        let suiteName = "DelayedStartCallouts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsContext(userDefaults: defaults)
        let spatial = RouteGuidanceTest.TestSpatialData(RouteGuidanceTest.TestMotionActivity(), manager)
        let generator = BeaconCalloutGenerator(data: spatial, geo: AppContext.shared.geolocationManager, settings: settings)
        let event = LocationUpdatedEvent(location(500))
        guard case .playCallouts(let group) = generator.handle(event: event, verbosity: .normal) else {
            return XCTFail("A muted delayed beacon must still generate distance callouts")
        }
        XCTAssertTrue(group.callouts.contains { $0 is DestinationCallout })
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .pending)
    }

    func testSleepDefersActivation() throws {
        let behavior = BehaviorBase()
        behaviorOverride = behavior
        behavior.sleep()
        defer { behavior.wake() }
        try setBeacon(distance: 500)
        manager.updateDelayedStart(for: location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        behavior.wake()
        manager.updateDelayedStart(for: location(200))
        XCTAssertTrue(manager.isAudioEnabled)
    }

    func testClearingReplacingAndDisablingCancelPendingStart() throws {
        try setBeacon(distance: 500)
        try manager.clearDestination()
        manager.updateDelayedStart(for: location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        try setBeacon(distance: 500)
        SettingsContext.shared.delayedStartEnabled = false
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        XCTAssertTrue(manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(500)))
        SettingsContext.shared.delayedStartEnabled = true
        manager.updateDelayedStart(for: location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        try setBeacon(distance: 500)
        manager.updateDelayedStart(for: location(200))
        XCTAssertTrue(manager.isAudioEnabled)
    }

    private func postLocation(_ user: CLLocation) {
        NotificationCenter.default.post(name: .locationUpdated, object: nil,
                                        userInfo: [SpatialDataContext.Keys.location: user])
    }

    func testGeofenceNotificationsMutePlayingBeaconAndDoNotRestart() throws {
        for enabled in [false, true] {
            SettingsContext.shared.delayedStartEnabled = enabled
            var arrivals = 0
            let observer = NotificationCenter.default.addObserver(forName: .destinationGeofenceDidTrigger,
                                                                  object: manager, queue: nil) { notification in
                if notification.userInfo?[DestinationManager.Keys.geofenceDidEnter] as? Bool == true {
                    arrivals += 1
                }
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            try setBeacon(distance: 500)
            postLocation(location(200))
            XCTAssertTrue(manager.isAudioEnabled)
            postLocation(location(5))
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertEqual(arrivals, 1)
            let starts = engine.starts
            postLocation(location(5))
            postLocation(location(30))
            postLocation(location(200))
            XCTAssertEqual(engine.starts, starts)
            XCTAssertFalse(manager.isAudioEnabled)
        }
    }

    func testDemoRestorationRespectsChangedArrivalDistanceWithSettingOnAndOff() throws {
        for enabled in [false, true] {
            SettingsContext.shared.delayedStartEnabled = enabled
            SettingsContext.shared.enterImmediateVicinityDistance = 10
            try setBeacon(distance: 30)
            XCTAssertTrue(manager.isAudioEnabled)
            let user = location(30)
            let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
            demo.prepare()
            SettingsContext.shared.enterImmediateVicinityDistance = 50
            demo.restoreState()
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertEqual(manager.delayedStartState, .inactive)
            let starts = engine.starts
            postLocation(user)
            postLocation(location(100))
            XCTAssertEqual(engine.starts, starts, "Restoring or leaving arrival must not restart audio")
        }
    }

    func testDemoRestorationChecksArrivalAfterReplacingDestination() throws {
        try setBeacon(distance: 500)
        var user = location(500)
        let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
        demo.prepare()
        demo.play(shouldTimeOut: false, newBeaconLocation: location(600))
        user = location(5)
        demo.restoreState()
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        postLocation(location(20))
        XCTAssertFalse(manager.isAudioEnabled)
    }

    func testDemoRestoresManualUnmuteBeyondActivationRadius() throws {
        try setBeacon(distance: 500)
        let user = location(500)
        manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: user)
        let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
        demo.prepare()
        demo.play(shouldTimeOut: false, newBeaconLocation: location(600))
        demo.restoreState()
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        XCTAssertEqual(manager.destination!.distanceToClosestLocation(from: destination), 0, accuracy: 0.1)
    }

    func testSettingOffThenOnDuringDemoDoesNotRestoreCanceledAutomaticDelay() throws {
        try setBeacon(distance: 500)
        let user = location(500)
        let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
        demo.prepare()
        demo.play(shouldTimeOut: false, newBeaconLocation: location(600))
        SettingsContext.shared.delayedStartEnabled = false
        SettingsContext.shared.delayedStartEnabled = true
        demo.restoreState()
        // Disabling canceled the delay and restored normal audio intent, even though ON
        // was selected again before returning to the original destination.
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
    }

    func testSettingOffThenOnDuringDemoDoesNotRearmManualMute() throws {
        try setBeacon(distance: 200)
        let user = location(200)
        manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: user)
        let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
        demo.prepare()
        demo.play(shouldTimeOut: false, newBeaconLocation: location(300))
        SettingsContext.shared.delayedStartEnabled = false
        SettingsContext.shared.delayedStartEnabled = true
        demo.restoreState()
        postLocation(location(400))
        postLocation(user)
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
    }

    func testPendingBeaconCannotStartWhileDemoIsOpenWithoutPlayingSample() throws {
        try setBeacon(distance: 500)
        var user = location(500)
        let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
        demo.prepare()
        user = location(200)
        postLocation(user)
        XCTAssertFalse(manager.isAudioEnabled)
        SettingsContext.shared.delayedStartEnabled = false
        XCTAssertFalse(manager.isAudioEnabled)
        demo.restoreState()
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
    }

    func testDemoDoesNotRestoreRemovedDestination() throws {
        for playSample in [false, true] {
            try setBeacon(distance: 500)
            let user = location(500)
            let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
            demo.prepare()
            if playSample { demo.play(shouldTimeOut: false, newBeaconLocation: location(600)) }
            try manager.clearDestination()
            demo.restoreState()
            postLocation(location(200))
            XCTAssertFalse(manager.isDestinationSet)
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertEqual(manager.delayedStartState, .inactive)
        }
    }

    func testDemoDoesNotOverwriteReplacementOrItsAudioIntent() throws {
        for enabled in [false, true] {
            SettingsContext.shared.delayedStartEnabled = enabled
            for playSample in [false, true] {
                try setBeacon(distance: 500)
                let user = location(500)
                let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
                demo.prepare()
                if playSample { demo.play(shouldTimeOut: false, newBeaconLocation: location(600)) }
                let key = try manager.setDestination(location: location(1000), address: nil,
                                                     enableAudio: false, userLocation: user)
                // A subsequent preview request must not take over the new destination either.
                demo.play(shouldTimeOut: false, newBeaconLocation: location(600))
                demo.restoreState()
                postLocation(location(800))
                XCTAssertEqual(manager.destinationKey, key)
                XCTAssertFalse(manager.isAudioEnabled)
                XCTAssertEqual(manager.delayedStartState, .inactive)
            }
        }
    }

    func testArrivalDuringSilentDemoCancelsSavedIntent() throws {
        for enabled in [false, true] {
            SettingsContext.shared.delayedStartEnabled = enabled
            try setBeacon(distance: 500)
            var user = location(500)
            let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
            demo.prepare()
            user = location(5)
            postLocation(user)
            user = location(500)
            postLocation(user)
            demo.restoreState()
            postLocation(location(200))
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertEqual(manager.delayedStartState, .inactive)
        }
    }

    private func makePreview() -> StreetPreviewBehavior {
        let node = Intersection()
        return StreetPreviewBehavior(at: IntersectionDecisionPoint(node: node),
                                     from: LocationDetail(location: destination),
                                     geolocationManager: AppContext.shared.geolocationManager,
                                     destinationManager: manager)
    }

    func testVirtualPreviewCannotActivateOrConsumeRealPendingBeacon() throws {
        try setBeacon(distance: 500)
        let originalKey = manager.destinationKey
        behaviorOverride = makePreview()
        postLocation(location(200))
        postLocation(location(5))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .pending)
        XCTAssertEqual(manager.destinationKey, originalKey)
        behaviorOverride = nil
        postLocation(location(500))
        XCTAssertFalse(manager.isAudioEnabled)
        postLocation(location(200))
        XCTAssertTrue(manager.isAudioEnabled)
    }

    func testDistantMarkerDemoPlaysWithoutBypassingOrdinaryDelayedStart() throws {
        for enabled in [false, true] {
            SettingsContext.shared.delayedStartEnabled = enabled
            try setBeacon(distance: 500)
            let user = location(500)
            let demo = BeaconDemoHelper(destinationManager: manager, userLocation: { user })
            demo.prepare()
            demo.play(shouldTimeOut: false, newBeaconLocation: location(1000))
            XCTAssertTrue(manager.isAudioEnabled, "The VoiceOver marker-edit preview must play beyond 300 meters")
            XCTAssertEqual(manager.delayedStartState, .inactive)
            demo.updateBeaconLocation(location(1200))
            XCTAssertTrue(manager.isAudioEnabled)
            manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: user)
            postLocation(user)
            XCTAssertFalse(manager.isAudioEnabled)
            demo.restoreState()
            XCTAssertEqual(manager.destination!.distanceToClosestLocation(from: destination), 0, accuracy: 0.1)
            XCTAssertEqual(manager.isAudioEnabled, !enabled)
            demo.prepare()
            demo.play(shouldTimeOut: false, newBeaconLocation: location(505))
            XCTAssertFalse(manager.isAudioEnabled, "Preview playback must still respect Arrival Distance")
            demo.restoreState()
            try setBeacon(distance: 500)
            XCTAssertEqual(manager.isAudioEnabled, !enabled)
            try setBeacon(distance: 500, enableAudio: false)
            XCTAssertFalse(manager.isAudioEnabled)
        }
    }

    func testSleepingArrivalWithBlockedGeofenceCancelsAutomaticWake() throws {
        for disableDuringSleep in [false, true] {
            SettingsContext.shared.delayedStartEnabled = true
            try setBeacon(distance: 500)
            let behavior = BehaviorBase(blockedAutoGenerators: [BeaconCalloutGenerator.self])
            behaviorOverride = behavior
            behavior.sleep()
            if disableDuringSleep { SettingsContext.shared.delayedStartEnabled = false }
            postLocation(location(5))
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertEqual(manager.delayedStartState, .inactive)
            postLocation(location(500))
            behavior.wake()
            postLocation(location(200))
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertFalse(manager.toggleDestinationAudio(false, automatic: true, forceMelody: true, userLocation: location(200)))
            XCTAssertTrue(manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(200)))
            XCTAssertTrue(manager.isAudioEnabled, "Arrival must not prevent an intentional manual unmute")
            behaviorOverride = nil
        }
    }

    func testSleepingWithoutArrivalRetainsPendingActivation() throws {
        try setBeacon(distance: 500)
        let behavior = BehaviorBase(blockedAutoGenerators: [BeaconCalloutGenerator.self])
        behaviorOverride = behavior
        behavior.sleep()
        postLocation(location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .pending)
        behavior.wake()
        postLocation(location(200))
        XCTAssertTrue(manager.isAudioEnabled)
    }

    func testRouteAndTourSleepArrivalDoesNotRestartPassedWaypoint() throws {
        let motion = RouteGuidanceTest.TestMotionActivity()
        let spatial = RouteGuidanceTest.TestSpatialData(motion, manager)
        for isTour in [false, true] {
            let navigation: BehaviorBase = isTour
                ? GuidedTour(navigationContent(), spatialData: spatial, motion: motion)
                : RouteGuidance(navigationContent(), spatialData: spatial, motion: motion)
            navigation.userLocation = location(500)
            behaviorOverride = navigation
            navigation.activate(with: nil)
            XCTAssertEqual(manager.delayedStartState, .pending)
            navigation.sleep()
            navigation.handleEvent(LocationUpdatedEvent(location(5)), completion: { _ in })
            postLocation(location(5))
            XCTAssertEqual(manager.delayedStartState, .inactive)
            postLocation(location(500))
            navigation.wake()
            postLocation(location(200))
            XCTAssertFalse(manager.isAudioEnabled)
            XCTAssertFalse(manager.toggleDestinationAudio(false, automatic: true, forceMelody: true, userLocation: location(200)))
            (navigation as? RouteGuidance)?.nextWaypoint()
            (navigation as? GuidedTour)?.nextWaypoint()
            XCTAssertEqual(manager.delayedStartState, .pending)
            postLocation(location(800))
            XCTAssertTrue(manager.isAudioEnabled)
            _ = navigation.deactivate()
            XCTAssertFalse(manager.isDestinationSet)
        }
    }

    func testSettingOffInVirtualPreviewWaitsForRealLocation() throws {
        try setBeacon(distance: 500)
        behaviorOverride = makePreview()
        postLocation(location(5))
        SettingsContext.shared.delayedStartEnabled = false
        XCTAssertFalse(manager.isAudioEnabled)
        SettingsContext.shared.delayedStartEnabled = true
        postLocation(location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        behaviorOverride = nil
        postLocation(location(500))
        XCTAssertTrue(manager.isAudioEnabled, "Normal audio should resume without reinstating the 300-meter delay")
    }

    func testDisablingRestoresOnlyAutomaticallyDelayedAudio() throws {
        try setBeacon(distance: 500)
        SettingsContext.shared.delayedStartEnabled = false
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        for distance in [200.0, 500.0] {
            SettingsContext.shared.delayedStartEnabled = true
            try setBeacon(distance: distance)
            if !manager.isAudioEnabled {
                manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(distance))
            }
            manager.toggleDestinationAudio(false, automatic: false, forceMelody: false, userLocation: location(distance))
            SettingsContext.shared.delayedStartEnabled = false
            postLocation(location(200))
            XCTAssertFalse(manager.isAudioEnabled, "OFF must preserve a manual mute inside or outside 300 meters")
        }
    }

    func testDisablingWhileAsleepDefersUntilWakeAndRespectsArrival() throws {
        for arrived in [false, true] {
            SettingsContext.shared.delayedStartEnabled = true
            try setBeacon(distance: 500)
            let sleeping = BehaviorBase()
            sleeping.sleep()
            behaviorOverride = sleeping
            SettingsContext.shared.delayedStartEnabled = false
            postLocation(location(arrived ? 5 : 200))
            XCTAssertFalse(manager.isAudioEnabled)
            sleeping.wake()
            postLocation(location(arrived ? 5 : 200))
            XCTAssertEqual(manager.isAudioEnabled, !arrived)
            behaviorOverride = nil
        }
    }

    func testDisablingWithoutLocationWaitsAndReplacementCancelsResume() throws {
        try setBeacon(distance: nil)
        SettingsContext.shared.delayedStartEnabled = false
        XCTAssertFalse(manager.isAudioEnabled)
        postLocation(location(500))
        XCTAssertTrue(manager.isAudioEnabled)
        SettingsContext.shared.delayedStartEnabled = true
        try setBeacon(distance: nil)
        SettingsContext.shared.delayedStartEnabled = false
        let other = location(2000)
        let key = try manager.setDestination(location: other, address: nil, enableAudio: false, userLocation: location(500))
        postLocation(location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.destinationKey, key)
        XCTAssertEqual(manager.delayedStartState, .inactive)
    }

    func testArrivalWhileAsleepCancelsResumeEvenAfterLeaving() throws {
        try setBeacon(distance: 500)
        let sleeping = BehaviorBase()
        sleeping.sleep()
        behaviorOverride = sleeping
        SettingsContext.shared.delayedStartEnabled = false
        postLocation(location(5))
        XCTAssertEqual(manager.delayedStartState, .inactive)
        postLocation(location(500))
        sleeping.wake()
        postLocation(location(200))
        XCTAssertFalse(manager.isAudioEnabled)
    }

    func testDisablingDuringAudioInterruptionWaitsUntilEngineStarted() throws {
        try setBeacon(distance: 500)
        func postState(_ state: AudioEngine.State) {
            NotificationCenter.default.post(name: .audioEngineStateChanged, object: engine,
                                            userInfo: [AudioEngine.Keys.audioEngineStateKey: state.rawValue])
        }
        postState(.stopped)
        SettingsContext.shared.delayedStartEnabled = false
        postLocation(location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        postState(.starting)
        postLocation(location(200))
        XCTAssertFalse(manager.isAudioEnabled)
        postState(.started)
        postLocation(location(200))
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(engine.starts, 1)
    }

    func testDifferentDestinationGetsFreshDelayAndOldArrivalCannotCancelIt() throws {
        try setBeacon(distance: 200)
        let oldKey = manager.destinationKey
        let key = try manager.setDestination(location: location(1000), address: nil, enableAudio: true, userLocation: location(200))
        XCTAssertNotEqual(key, oldKey)
        XCTAssertFalse(manager.isAudioEnabled)
        postLocation(destination)
        XCTAssertEqual(manager.delayedStartState, .pending)
        postLocation(location(800))
        XCTAssertTrue(manager.isAudioEnabled)
        XCTAssertEqual(manager.destinationKey, key)
    }


    private final class NavigationDelegate: BehaviorDelegate {
        weak var owner: Behavior?
        func interruptCurrent(clearQueue: Bool, playHush: Bool) { }
        func process(_ event: Event) {
            owner?.handleEvent(event, completion: { _ in })
        }
    }

    private func navigationContent() -> AuthoredActivityContent {
        AuthoredActivityContent(id: "delayed-start-\(UUID().uuidString)", type: .guidedTour,
                                name: "Delayed Start regression", creator: "UnitTests", locale: .enUS,
                                availability: RouteGuidanceTest.availableInterval, expires: false, image: nil, desc: "",
                                waypoints: [ActivityWaypoint(coordinate: destination.coordinate),
                                            ActivityWaypoint(coordinate: location(1000).coordinate)], pois: [])
    }

    func testRouteWaypointReplacementArrivalAndCompletion() throws {
        let motion = RouteGuidanceTest.TestMotionActivity()
        let spatial = RouteGuidanceTest.TestSpatialData(motion, manager)
        let route = RouteGuidance(navigationContent(), spatialData: spatial, motion: motion)
        let delegate = NavigationDelegate()
        delegate.owner = route
        route.delegate = delegate
        route.userLocation = location(500)
        behaviorOverride = route
        route.activate(with: nil)
        defer { _ = route.deactivate() }
        delegate.process(RouteGuidanceReadyEvent())
        let firstKey = manager.destinationKey
        XCTAssertNotNil(firstKey)
        XCTAssertFalse(manager.isAudioEnabled)
        route.nextWaypoint()
        XCTAssertNotEqual(manager.destinationKey, firstKey)
        XCTAssertFalse(manager.isAudioEnabled)
        route.previousWaypoint()
        XCTAssertEqual(route.currentWaypoint?.index, 0)
        postLocation(location(200))
        XCTAssertTrue(manager.isAudioEnabled)

        // Production processes the behavior's location event before the notification.
        delegate.process(LocationUpdatedEvent(destination))
        postLocation(destination)
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(route.state.visited, [0])
        route.finishTransitioningBeacon()
        XCTAssertEqual(route.currentWaypoint?.index, 1)
        XCTAssertEqual(manager.delayedStartState, .pending)
        postLocation(destination)
        XCTAssertFalse(manager.isAudioEnabled)
        postLocation(location(800))
        XCTAssertTrue(manager.isAudioEnabled)
        delegate.process(LocationUpdatedEvent(location(1000)))
        postLocation(location(1000))
        XCTAssertTrue(route.progress.isDone)
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        postLocation(location(800))
        XCTAssertFalse(manager.isAudioEnabled)
    }

    func testTourWaypointReplacementArrivalAndCompletion() throws {
        let motion = RouteGuidanceTest.TestMotionActivity()
        let spatial = RouteGuidanceTest.TestSpatialData(motion, manager)
        let tour = GuidedTour(navigationContent(), spatialData: spatial, motion: motion)
        let delegate = NavigationDelegate()
        delegate.owner = tour
        tour.delegate = delegate
        tour.userLocation = location(500)
        behaviorOverride = tour
        tour.activate(with: nil)
        defer { _ = tour.deactivate() }
        delegate.process(TourReadyEvent())
        let firstKey = manager.destinationKey
        XCTAssertNotNil(firstKey)
        XCTAssertFalse(manager.isAudioEnabled)
        tour.nextWaypoint()
        XCTAssertNotEqual(manager.destinationKey, firstKey)
        XCTAssertFalse(manager.isAudioEnabled)
        tour.previousWaypoint()
        postLocation(location(200))
        XCTAssertTrue(manager.isAudioEnabled)
        delegate.process(LocationUpdatedEvent(destination))
        postLocation(destination)
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(tour.state.visited, [0])
        tour.finishTransitioningBeacon()
        XCTAssertEqual(tour.currentWaypoint?.index, 1)
        XCTAssertEqual(manager.delayedStartState, .pending)
        postLocation(destination)
        XCTAssertFalse(manager.isAudioEnabled)
        postLocation(location(800))
        XCTAssertTrue(manager.isAudioEnabled)
        delegate.process(LocationUpdatedEvent(location(1000)))
        postLocation(location(1000))
        XCTAssertTrue(tour.progress.isDone)
        XCTAssertFalse(manager.isAudioEnabled)
        XCTAssertEqual(manager.delayedStartState, .inactive)
        postLocation(location(800))
        XCTAssertFalse(manager.isAudioEnabled)
    }

    func testCompletionCancelsPendingStartWithoutNeedingAnotherLocationFix() throws {
        let motion = RouteGuidanceTest.TestMotionActivity()
        let spatial = RouteGuidanceTest.TestSpatialData(motion, manager)
        let route = RouteGuidance(navigationContent(), spatialData: spatial, motion: motion)
        route.userLocation = location(500)
        behaviorOverride = route
        route.activate(with: nil)
        route.nextWaypoint()
        XCTAssertEqual(manager.delayedStartState, .pending)
        XCTAssertTrue(route.completeCurrentWaypoint())
        XCTAssertEqual(manager.delayedStartState, .inactive)
        postLocation(location(800))
        XCTAssertFalse(manager.isAudioEnabled)
        _ = route.deactivate()
        XCTAssertFalse(manager.isDestinationSet)

        let tour = GuidedTour(navigationContent(), spatialData: spatial, motion: motion)
        tour.userLocation = location(500)
        behaviorOverride = tour
        tour.activate(with: nil)
        tour.nextWaypoint()
        XCTAssertEqual(manager.delayedStartState, .pending)
        XCTAssertTrue(tour.completeCurrentWaypoint())
        XCTAssertEqual(manager.delayedStartState, .inactive)
        postLocation(location(800))
        XCTAssertFalse(manager.isAudioEnabled)
        _ = tour.deactivate()
        XCTAssertFalse(manager.isDestinationSet)
    }

}
