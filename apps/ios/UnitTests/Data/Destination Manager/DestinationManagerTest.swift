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
}
