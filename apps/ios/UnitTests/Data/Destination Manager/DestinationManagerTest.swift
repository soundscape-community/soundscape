//
//  DestinationManagerTest.swift
//  UnitTests
//
//  Created by Kai on 10/3/23.
//  Copyright © 2023 Microsoft. All rights reserved.
//  Copyright (c) Soundscape Community Contributers.
//

import XCTest
import CoreLocation
import SSGeo
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
        var destinationPOIForReferenceIDHandler: ((String) -> POI?)?
        var destinationEntityKeyForReferenceIDHandler: ((String) -> String?)?
        var destinationIsTemporaryForReferenceIDHandler: ((String) -> Bool)?
        var destinationNicknameForReferenceIDHandler: ((String) -> String?)?
        var destinationEstimatedAddressForReferenceIDHandler: ((String) -> String?)?
        var markReferenceEntitySelectedHandler: ((String) throws -> Void)?
        var setReferenceEntityTemporaryHandler: ((String, Bool) throws -> Void)?
        var referenceEntityIDForGenericLocationHandler: ((GenericLocation) -> String?)?
        var referenceEntityIDForEntityKeyHandler: ((String) -> String?)?
        var addTemporaryReferenceEntityHandler: ((GenericLocation, String?) throws -> String)?
        var addTemporaryReferenceEntityWithNicknameHandler: ((GenericLocation, String?, String?) throws -> String)?
        var addTemporaryReferenceEntityForEntityKeyHandler: ((String, String?) throws -> String)?
        var removeAllTemporaryReferenceEntitiesHandler: (() throws -> Void)?

        func destinationPOI(forReferenceID id: String) -> POI? {
            destinationPOIForReferenceIDHandler?(id)
        }

        func destinationEntityKey(forReferenceID id: String) -> String? {
            destinationEntityKeyForReferenceIDHandler?(id)
        }

        func destinationIsTemporary(forReferenceID id: String) -> Bool {
            destinationIsTemporaryForReferenceIDHandler?(id) ?? false
        }

        func destinationNickname(forReferenceID id: String) -> String? {
            destinationNicknameForReferenceIDHandler?(id)
        }

        func destinationEstimatedAddress(forReferenceID id: String) -> String? {
            destinationEstimatedAddressForReferenceIDHandler?(id)
        }

        func markReferenceEntitySelected(forReferenceID id: String) throws {
            try markReferenceEntitySelectedHandler?(id)
        }

        func setReferenceEntityTemporary(forReferenceID id: String, temporary: Bool) throws {
            if let setReferenceEntityTemporaryHandler {
                try setReferenceEntityTemporaryHandler(id, temporary)
            }
        }

        func referenceEntityID(forGenericLocation location: GenericLocation) async -> String? {
            referenceEntityIDForGenericLocationHandler?(location) ?? nil
        }

        func referenceEntityID(forEntityKey key: String) async -> String? {
            referenceEntityIDForEntityKeyHandler?(key) ?? nil
        }

        func addTemporaryReferenceEntity(location: GenericLocation, estimatedAddress: String?) async throws -> String {
            guard let handler = addTemporaryReferenceEntityHandler else {
                XCTFail("addTemporaryReferenceEntityHandler was not set")
                throw DestinationManagerError.referenceEntityDoesNotExist
            }
            return try handler(location, estimatedAddress)
        }

        func addTemporaryReferenceEntity(location: GenericLocation, nickname: String?, estimatedAddress: String?) async throws -> String {
            guard let handler = addTemporaryReferenceEntityWithNicknameHandler else {
                XCTFail("addTemporaryReferenceEntityWithNicknameHandler was not set")
                throw DestinationManagerError.referenceEntityDoesNotExist
            }
            return try handler(location, nickname, estimatedAddress)
        }

        func addTemporaryReferenceEntity(entityKey: String, estimatedAddress: String?) async throws -> String {
            guard let handler = addTemporaryReferenceEntityForEntityKeyHandler else {
                XCTFail("addTemporaryReferenceEntityForEntityKeyHandler was not set")
                throw DestinationManagerError.referenceEntityDoesNotExist
            }
            return try handler(entityKey, estimatedAddress)
        }

        func removeAllTemporaryReferenceEntities() async throws {
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
    
    func testBasicDestination() async throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        XCTAssertFalse(dm.isDestinationSet)
        let ref_entity = try await dm.setDestinationAsync(location: sage_burdett_coord,
                                                          address: nil,
                                                          enableAudio: false,
                                                          userLocation: barton_front_coord,
                                                          logContext: nil)
        XCTAssertFalse(dm.isUserWithinGeofence(barton_front_coord)) // we are not at the destination
        XCTAssertTrue(dm.isDestinationSet)
        XCTAssertTrue(dm.isDestination(key: ref_entity))
        XCTAssertFalse(dm.isDestination(key: "asdf (:"))
        XCTAssertFalse(dm.isDestination(key: ref_entity + "AA"))
        
        // clear destination
        
        try await dm.clearDestinationAsync(logContext: nil)
        XCTAssertFalse(dm.isDestinationSet)
        XCTAssertFalse(dm.isAudioEnabled)
        // clearing should delete our temporary destination location, meaning this should error:
        do {
            try await dm.setDestinationAsync(referenceID: ref_entity, enableAudio: false, userLocation: nil, logContext: nil)
            XCTFail("Expected setting destination for a removed temporary reference entity to throw")
        } catch DestinationManagerError.referenceEntityDoesNotExist {
            // Expected for deleted temporary destination entities.
        } catch {
            XCTFail("Expected DestinationManagerError.referenceEntityDoesNotExist, got \(error)")
        }
    }

    func testDestinationChangedNotificationIncludesDestinationPOI() async throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        let destinationSetExpectation = expectation(description: "destination changed includes destination POI")
        var receivedDestinationPOIKey: String?
        let token = NotificationCenter.default.addObserver(forName: .destinationChanged, object: dm, queue: .main) { notification in
            guard notification.userInfo?[DestinationManager.Keys.destinationKey] as? String != nil else {
                return
            }

            receivedDestinationPOIKey = (notification.userInfo?[DestinationManager.Keys.destinationPOI] as? POI)?.key
            destinationSetExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(token)
        }

        let destinationID = try await dm.setDestinationAsync(location: sage_burdett_coord,
                                                             address: nil,
                                                             enableAudio: false,
                                                             userLocation: barton_front_coord,
                                                             logContext: nil)

        await fulfillment(of: [destinationSetExpectation], timeout: 1.0)
        XCTAssertEqual(receivedDestinationPOIKey, destinationID)

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testDestinationChangedNotificationIncludesDestinationEntityKey() async throws {
        let testID = "test-reference-id"
        let expectedEntityKey = "entity-key-123"
        let store = MockDestinationEntityStore()
        let destinationSetExpectation = expectation(description: "destination changed includes destination entity key")
        var receivedDestinationEntityKey: String?

        store.destinationPOIForReferenceIDHandler = { _ in
            GenericLocation(lat: 42.7290570, lon: -73.6726370, name: "Test Destination")
        }
        store.destinationEntityKeyForReferenceIDHandler = { _ in
            expectedEntityKey
        }
        store.markReferenceEntitySelectedHandler = { _ in }
        store.removeAllTemporaryReferenceEntitiesHandler = { }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        let token = NotificationCenter.default.addObserver(forName: .destinationChanged, object: dm, queue: .main) { notification in
            guard notification.userInfo?[DestinationManager.Keys.destinationKey] as? String != nil else {
                return
            }

            receivedDestinationEntityKey = notification.userInfo?[DestinationManager.Keys.destinationEntityKey] as? String
            destinationSetExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(token)
        }

        try await dm.setDestinationAsync(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        await fulfillment(of: [destinationSetExpectation], timeout: 1.0)
        XCTAssertEqual(receivedDestinationEntityKey, expectedEntityKey)

        try await dm.clearDestinationAsync(logContext: nil)
    }
    
    /// geofence is within `EnterImmediateVicinityDistance` and `LeaveImmediateVicinityDistance` of the destination
    func testDestinationInGeoFence() async throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        _ = try await dm.setDestinationAsync(location: rpi_bridge_east,
                                             address: nil,
                                             enableAudio: true,
                                             userLocation: rpi_bridge_east,
                                             logContext: nil)
        XCTAssertFalse(dm.isAudioEnabled) // since we are already at the destination, audio should be disabled
        XCTAssertTrue(dm.isUserWithinGeofence(rpi_bridge_east)) // we are at the destination
        XCTAssertFalse(dm.isUserWithinGeofence(rpi_bridge_west)) // if we were across the bridge we would not be
        // (how close is the other side of the bridge? should it be?)
        XCTAssertFalse(dm.isUserWithinGeofence(barton_front_coord)) // definitely not from barton hall
        
        // clear destination
        
        try await dm.clearDestinationAsync(logContext: nil)
        XCTAssertFalse(dm.isDestinationSet)
        XCTAssertFalse(dm.isAudioEnabled)
        XCTAssertFalse(dm.isUserWithinGeofence(rpi_bridge_east)) // no longer in geofence as it is gone
        XCTAssertFalse(dm.isUserWithinGeofence(rpi_bridge_west)) // and still across the bridge isn't either
    }

    func testSetDestinationUsesInjectedEntityStoreLookup() async throws {
        let testID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7290570,
                                                                                                              lon: -73.6726370,
                                                                                                              name: "Test"),
                                                                                    estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var lookedUpPOIIDs: [String] = []
        var selectedIDs: [String] = []
        var removeAllTemporaryCallCount = 0

        store.destinationPOIForReferenceIDHandler = { id in
            lookedUpPOIIDs.append(id)
            return SpatialDataCache.referenceEntityByKey(id)?.getPOI()
        }
        store.markReferenceEntitySelectedHandler = { id in
            selectedIDs.append(id)
        }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            removeAllTemporaryCallCount += 1
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.setDestinationAsync(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        XCTAssertEqual(lookedUpPOIIDs.first, testID)
        XCTAssertEqual(selectedIDs, [testID])
        XCTAssertTrue(dm.isDestinationSet)

        try await dm.clearDestinationAsync(logContext: nil)
        XCTAssertEqual(removeAllTemporaryCallCount, 1)
    }

    func testIsDestinationUsesInjectedEntityStoreEntityKeyLookup() async throws {
        let testID = "test-reference-id"
        let expectedEntityKey = "entity-key-123"
        let store = MockDestinationEntityStore()
        var lookedUpEntityKeyIDs: [String] = []

        store.destinationPOIForReferenceIDHandler = { _ in
            GenericLocation(lat: 42.7290570, lon: -73.6726370, name: "Test Destination")
        }
        store.destinationEntityKeyForReferenceIDHandler = { id in
            lookedUpEntityKeyIDs.append(id)
            return expectedEntityKey
        }
        store.markReferenceEntitySelectedHandler = { _ in }
        store.removeAllTemporaryReferenceEntitiesHandler = { }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.setDestinationAsync(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        XCTAssertTrue(dm.isDestination(key: testID))
        XCTAssertTrue(dm.isDestination(key: expectedEntityKey))
        XCTAssertFalse(dm.isDestination(key: "other-entity-key"))
        XCTAssertEqual(lookedUpEntityKeyIDs, [testID, testID, testID])

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testDestinationPOIUsesInjectedEntityStorePOILookup() async throws {
        let testID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7290570,
                                                                                                              lon: -73.6726370,
                                                                                                              name: "Test POI"),
                                                                                    estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var lookedUpPOIIDs: [String] = []

        store.destinationPOIForReferenceIDHandler = { id in
            lookedUpPOIIDs.append(id)
            return SpatialDataCache.referenceEntityByKey(id)?.getPOI()
        }
        store.markReferenceEntitySelectedHandler = { _ in }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.setDestinationAsync(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        XCTAssertNotNil(dm.destinationPOI(forReferenceID: testID))
        XCTAssertGreaterThanOrEqual(lookedUpPOIIDs.count, 2)
        XCTAssertEqual(Array(lookedUpPOIIDs.prefix(2)), [testID, testID])

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testDestinationMetadataUsesInjectedEntityStoreMetadataLookup() async throws {
        let testID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7290570,
                                                                                                              lon: -73.6726370,
                                                                                                              name: "Test Metadata"),
                                                                                    estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var temporaryLookupIDs: [String] = []
        var nicknameLookupIDs: [String] = []
        var estimatedAddressLookupIDs: [String] = []

        store.destinationPOIForReferenceIDHandler = { id in
            SpatialDataCache.referenceEntityByKey(id)?.getPOI()
        }
        store.destinationIsTemporaryForReferenceIDHandler = { id in
            temporaryLookupIDs.append(id)
            return true
        }
        store.destinationNicknameForReferenceIDHandler = { id in
            nicknameLookupIDs.append(id)
            return "HeadsetTest"
        }
        store.destinationEstimatedAddressForReferenceIDHandler = { id in
            estimatedAddressLookupIDs.append(id)
            return "123 Test St"
        }
        store.markReferenceEntitySelectedHandler = { _ in }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.setDestinationAsync(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        XCTAssertTrue(dm.destinationIsTemporary(forReferenceID: testID))
        XCTAssertEqual(dm.destinationNickname, "HeadsetTest")
        XCTAssertEqual(dm.destinationEstimatedAddress, "123 Test St")
        XCTAssertEqual(temporaryLookupIDs, [testID])
        XCTAssertEqual(nicknameLookupIDs, [testID])
        XCTAssertEqual(estimatedAddressLookupIDs, [testID])

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testSetDestinationTemporaryIfMatchingIDUsesInjectedEntityStoreTemporaryMutation() async throws {
        let testID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7290570,
                                                                                                              lon: -73.6726370,
                                                                                                              name: "Test Temporary"),
                                                                                    estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var setTemporaryCalls: [(id: String, temporary: Bool)] = []

        store.destinationPOIForReferenceIDHandler = { id in
            SpatialDataCache.referenceEntityByKey(id)?.getPOI()
        }
        store.setReferenceEntityTemporaryHandler = { id, temporary in
            setTemporaryCalls.append((id: id, temporary: temporary))
        }
        store.markReferenceEntitySelectedHandler = { _ in }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.setDestinationAsync(referenceID: testID, enableAudio: false, userLocation: nil, logContext: nil)

        XCTAssertTrue(try dm.setDestinationTemporaryIfMatchingID(testID))
        XCTAssertFalse(try dm.setDestinationTemporaryIfMatchingID("different-id"))
        XCTAssertEqual(setTemporaryCalls.count, 1)
        XCTAssertEqual(setTemporaryCalls.first?.id, testID)
        XCTAssertEqual(setTemporaryCalls.first?.temporary, true)

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testClearDestinationUsesInjectedEntityStoreCleanup() async throws {
        let store = MockDestinationEntityStore()
        var removeAllTemporaryCallCount = 0

        store.removeAllTemporaryReferenceEntitiesHandler = {
            removeAllTemporaryCallCount += 1
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.clearDestinationAsync(logContext: nil)

        XCTAssertEqual(removeAllTemporaryCallCount, 1)
    }

    func testClearDestinationAsyncUsesInjectedEntityStoreCleanup() async throws {
        let store = MockDestinationEntityStore()
        var removeAllTemporaryCallCount = 0

        store.removeAllTemporaryReferenceEntitiesHandler = {
            removeAllTemporaryCallCount += 1
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        try await dm.clearDestinationAsync(logContext: nil)

        XCTAssertEqual(removeAllTemporaryCallCount, 1)
    }

    func testClearStartupTemporaryDestinationIfNeededClearsLegacyTemporaryRouteGuidanceBeacon() async throws {
        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading)
        let location = GenericLocation(lat: 42.7290570, lon: -73.6726370, name: RouteGuidance.name)

        _ = try await dm.setDestinationAsync(location: location,
                                             address: nil,
                                             enableAudio: false,
                                             userLocation: nil,
                                             logContext: nil)
        XCTAssertTrue(dm.isDestinationSet)

        await dm.clearStartupTemporaryDestinationIfNeeded()

        XCTAssertFalse(dm.isDestinationSet)
        XCTAssertNil(dm.destinationKey)
    }

    func testSetDestinationGenericLocationUsesInjectedEntityIDLookup() async throws {
        let existingID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7290570,
                                                                                                                  lon: -73.6726370,
                                                                                                                  name: "Test Generic"),
                                                                                        estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var lookedUpLocations: [SSGeoCoordinate] = []
        var addTemporaryCallCount = 0

        store.referenceEntityIDForGenericLocationHandler = { location in
            lookedUpLocations.append(location.geoCoordinate)
            return existingID
        }
        store.destinationPOIForReferenceIDHandler = { id in
            XCTAssertEqual(id, existingID)
            return GenericLocation(lat: 42.7292000, lon: -73.6727000, name: "Existing Entity Key Destination")
        }
        store.addTemporaryReferenceEntityHandler = { _, _ in
            addTemporaryCallCount += 1
            return UUID().uuidString
        }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        let location = GenericLocation(lat: 42.7290570, lon: -73.6726370, name: "Test Generic")
        let returnedID = try await dm.setDestinationAsync(location: location,
                                                          address: nil,
                                                          enableAudio: false,
                                                          userLocation: nil,
                                                          logContext: nil)

        XCTAssertEqual(returnedID, existingID)
        XCTAssertEqual(lookedUpLocations.count, 1)
        XCTAssertEqual(addTemporaryCallCount, 0)

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testSetDestinationGenericLocationAsyncUsesInjectedEntityIDLookup() async throws {
        let existingID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7290570,
                                                                                                                  lon: -73.6726370,
                                                                                                                  name: "Test Generic Async"),
                                                                                        estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var lookedUpLocations: [SSGeoCoordinate] = []
        var addTemporaryCallCount = 0

        store.referenceEntityIDForGenericLocationHandler = { location in
            lookedUpLocations.append(location.geoCoordinate)
            return existingID
        }
        store.destinationPOIForReferenceIDHandler = { id in
            XCTAssertEqual(id, existingID)
            return GenericLocation(lat: 42.7292000, lon: -73.6727000, name: "Existing Entity Key Destination Async")
        }
        store.addTemporaryReferenceEntityHandler = { _, _ in
            addTemporaryCallCount += 1
            return UUID().uuidString
        }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        let location = GenericLocation(lat: 42.7290570, lon: -73.6726370, name: "Test Generic Async")
        let returnedID = try await dm.setDestinationAsync(location: location,
                                                          address: nil,
                                                          enableAudio: false,
                                                          userLocation: nil,
                                                          logContext: nil)

        XCTAssertEqual(returnedID, existingID)
        XCTAssertEqual(lookedUpLocations.count, 1)
        XCTAssertEqual(addTemporaryCallCount, 0)

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testSetDestinationEntityKeyUsesInjectedEntityIDLookup() async throws {
        let existingID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7292000,
                                                                                                                  lon: -73.6727000,
                                                                                                                  name: "Test Entity Key"),
                                                                                        estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var lookedUpEntityKeys: [String] = []
        var addTemporaryCallCount = 0

        store.referenceEntityIDForEntityKeyHandler = { key in
            lookedUpEntityKeys.append(key)
            return existingID
        }
        store.destinationPOIForReferenceIDHandler = { id in
            XCTAssertEqual(id, existingID)
            return GenericLocation(lat: 42.7292000, lon: -73.6727000, name: "Existing Entity Key Destination")
        }
        store.addTemporaryReferenceEntityForEntityKeyHandler = { _, _ in
            addTemporaryCallCount += 1
            return UUID().uuidString
        }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        let returnedID = try await dm.setDestinationAsync(entityKey: "entity-key-123",
                                                          enableAudio: false,
                                                          userLocation: nil,
                                                          estimatedAddress: nil,
                                                          logContext: nil)

        XCTAssertEqual(returnedID, existingID)
        XCTAssertEqual(lookedUpEntityKeys, ["entity-key-123"])
        XCTAssertEqual(addTemporaryCallCount, 0)

        try await dm.clearDestinationAsync(logContext: nil)
    }

    func testSetDestinationEntityKeyAsyncUsesInjectedEntityIDLookup() async throws {
        let existingID = try SpatialDataStoreRegistry.store.addTemporaryReferenceEntity(location: GenericLocation(lat: 42.7292000,
                                                                                                                  lon: -73.6727000,
                                                                                                                  name: "Test Entity Key Async"),
                                                                                        estimatedAddress: nil)
        let store = MockDestinationEntityStore()
        var lookedUpEntityKeys: [String] = []
        var addTemporaryCallCount = 0

        store.referenceEntityIDForEntityKeyHandler = { key in
            lookedUpEntityKeys.append(key)
            return existingID
        }
        store.destinationPOIForReferenceIDHandler = { id in
            XCTAssertEqual(id, existingID)
            return GenericLocation(lat: 42.7292000, lon: -73.6727000, name: "Existing Entity Key Destination Async")
        }
        store.addTemporaryReferenceEntityForEntityKeyHandler = { _, _ in
            addTemporaryCallCount += 1
            return UUID().uuidString
        }
        store.removeAllTemporaryReferenceEntitiesHandler = {
            try SpatialDataStoreRegistry.store.removeAllTemporaryReferenceEntities()
        }

        let dm = DestinationManager(audioEngine: basic_audio_engine, collectionHeading: empty_heading, destinationStore: store)
        let returnedID = try await dm.setDestinationAsync(entityKey: "entity-key-async-123",
                                                          enableAudio: false,
                                                          userLocation: nil,
                                                          estimatedAddress: nil,
                                                          logContext: nil)

        XCTAssertEqual(returnedID, existingID)
        XCTAssertEqual(lookedUpEntityKeys, ["entity-key-async-123"])
        XCTAssertEqual(addTemporaryCallCount, 0)

        try await dm.clearDestinationAsync(logContext: nil)
    }
    
    

}
