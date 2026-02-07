//
//  DestinationManagerTest.swift
//  UnitTests
//
//  Created by Kai on 10/3/23.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
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

    @MainActor
    final class MockDestinationEntityStore: DestinationEntityStore {
        var referenceEntityForReferenceIDHandler: ((String) -> ReferenceEntity?)?
        var referenceEntityForGenericLocationHandler: ((GenericLocation) -> ReferenceEntity?)?
        var referenceEntityForEntityKeyHandler: ((String) -> ReferenceEntity?)?
        var addTemporaryReferenceEntityHandler: ((GenericLocation, String?) throws -> String)?
        var addTemporaryReferenceEntityWithNicknameHandler: ((GenericLocation, String?, String?) throws -> String)?
        var addTemporaryReferenceEntityForEntityKeyHandler: ((String, String?) throws -> String)?
        var removeAllTemporaryReferenceEntitiesHandler: (() throws -> Void)?

        func referenceEntity(forReferenceID id: String) -> ReferenceEntity? {
            referenceEntityForReferenceIDHandler?(id) ?? nil
        }

        func referenceEntity(forGenericLocation location: GenericLocation) -> ReferenceEntity? {
            referenceEntityForGenericLocationHandler?(location) ?? nil
        }

        func referenceEntity(forEntityKey key: String) -> ReferenceEntity? {
            referenceEntityForEntityKeyHandler?(key) ?? nil
        }

        func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) throws -> String {
            guard let handler = addTemporaryReferenceEntityHandler else {
                XCTFail("addTemporaryReferenceEntityHandler was not set")
                throw DestinationManagerError.referenceEntityDoesNotExist
            }
            return try handler(location, estimatedAddress)
        }

        func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) throws -> String {
            guard let handler = addTemporaryReferenceEntityWithNicknameHandler else {
                XCTFail("addTemporaryReferenceEntityWithNicknameHandler was not set")
                throw DestinationManagerError.referenceEntityDoesNotExist
            }
            return try handler(location, nickname, estimatedAddress)
        }

        func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) throws -> String {
            guard let handler = addTemporaryReferenceEntityForEntityKeyHandler else {
                XCTFail("addTemporaryReferenceEntityForEntityKeyHandler was not set")
                throw DestinationManagerError.referenceEntityDoesNotExist
            }
            return try handler(entityKey, estimatedAddress)
        }

        func removeAllTemporaryReferenceEntities() throws {
            try removeAllTemporaryReferenceEntitiesHandler?()
        }
    }
    
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

    func testSetDestinationUsesInjectedEntityStoreLookup() throws {
        let testID = try ReferenceEntity.add(location: GenericLocation(lat: 42.7290570, lon: -73.6726370, name: "Test"), estimatedAddress: nil, temporary: true)
        let store = MockDestinationEntityStore()
        var lookedUpIDs: [String] = []
        var removeAllTemporaryCallCount = 0

        store.referenceEntityForReferenceIDHandler = { id in
            lookedUpIDs.append(id)
            return SpatialDataCache.referenceEntityByKey(id)
        }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            removeAllTemporaryCallCount += 1
            try ReferenceEntity.removeAllTemporary()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try dm.setDestination(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        XCTAssertEqual(lookedUpIDs.first, testID)
        XCTAssertTrue(dm.isDestinationSet)

        try dm.clearDestination()
        XCTAssertEqual(removeAllTemporaryCallCount, 1)
    }

    func testClearDestinationUsesInjectedEntityStoreCleanup() throws {
        let store = MockDestinationEntityStore()
        var removeAllTemporaryCallCount = 0

        store.removeAllTemporaryReferenceEntitiesHandler = {
            removeAllTemporaryCallCount += 1
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try dm.clearDestination()

        XCTAssertEqual(removeAllTemporaryCallCount, 1)
    }
    
    

}
