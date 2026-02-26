//
//  DestinationManagerProtocol.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation
import SSGeo

protocol DestinationManagerProtocol: AnyObject {
    
    // MARK: Properties
    
    var destinationKey: String? { get }
    
    var isDestinationSet: Bool { get }
    @MainActor var destinationNickname: String? { get }
    @MainActor var destinationEstimatedAddress: String? { get }
    
    var isAudioEnabled: Bool { get }
    
    var isBeaconInBounds: Bool { get }
    
    var isCurrentBeaconAsyncFinishable: Bool { get }
    
    var beaconPlayerId: AudioPlayerIdentifier? { get }
    var proximityBeaconPlayerId: AudioPlayerIdentifier? { get }
    
    // MARK: Methods
    
    func isUserWithinGeofence(_ userLocation: CLLocation) -> Bool
    
    func isDestination(key: String) -> Bool
    func destinationIsTemporary(forReferenceID id: String) -> Bool
    func destinationPOI(forReferenceID id: String) -> POI?
    func destinationEntityKey(forReferenceID id: String) -> String?

    func setDestinationAsync(referenceID: String, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) async throws
    
    @discardableResult
    func setDestinationAsync(location: CLLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) async throws -> String

    @discardableResult
    func setDestinationAsync(location: GenericLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) async throws -> String
    
    @discardableResult
    func setDestinationAsync(entityKey: String, enableAudio: Bool, userLocation: CLLocation?, estimatedAddress: String?, logContext: String?) async throws -> String
    
    @discardableResult
    func setDestinationAsync(location: CLLocation, behavior: String, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) async throws -> String

    func clearDestinationAsync(logContext: String?) async throws

    @MainActor @discardableResult
    func setDestinationTemporaryIfMatchingID(_ id: String) throws -> Bool
    
    @discardableResult
    func toggleDestinationAudio(_ sendNotfication: Bool, automatic: Bool, forceMelody: Bool) -> Bool
    
    @discardableResult
    func updateDestinationLocation(_ newLocation: CLLocation, userLocation: CLLocation) -> Bool

    func clearStartupTemporaryDestinationIfNeeded() async
}

// This extension adds the ability to not pass the `logContext` argument
extension DestinationManagerProtocol {
    func isUserWithinGeofence(_ userLocation: SSGeoLocation) -> Bool {
        return isUserWithinGeofence(userLocation.clLocation)
    }

    func setDestinationAsync(referenceID: String, enableAudio: Bool, userLocation: CLLocation?) async throws {
        try await setDestinationAsync(referenceID: referenceID, enableAudio: enableAudio, userLocation: userLocation, logContext: nil)
    }
    
    @discardableResult
    func setDestinationAsync(location: CLLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?) async throws -> String {
        try await setDestinationAsync(location: location, address: address, enableAudio: enableAudio, userLocation: userLocation, logContext: nil)
    }

    @discardableResult
    func setDestinationAsync(location: GenericLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?) async throws -> String {
        try await setDestinationAsync(location: location, address: address, enableAudio: enableAudio, userLocation: userLocation, logContext: nil)
    }

    @discardableResult
    func setDestinationAsync(entityKey: String, enableAudio: Bool, userLocation: CLLocation?, estimatedAddress: String?) async throws -> String {
        try await setDestinationAsync(entityKey: entityKey, enableAudio: enableAudio, userLocation: userLocation, estimatedAddress: estimatedAddress, logContext: nil)
    }
    
    @discardableResult
    func setDestinationAsync(location: CLLocation, behavior: String, enableAudio: Bool, userLocation: CLLocation?) async throws -> String {
        try await setDestinationAsync(location: location, behavior: behavior, enableAudio: enableAudio, userLocation: userLocation, logContext: nil)
    }

    func clearDestinationAsync() async throws {
        try await clearDestinationAsync(logContext: nil)
    }
    
    @discardableResult
    func toggleDestinationAudio(_ sendNotfication: Bool = true, automatic: Bool = true, forceMelody: Bool = false) -> Bool {
        return toggleDestinationAudio(sendNotfication, automatic: automatic, forceMelody: forceMelody)
    }

}
