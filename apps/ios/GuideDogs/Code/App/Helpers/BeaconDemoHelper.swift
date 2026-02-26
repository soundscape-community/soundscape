//
//  BeaconDemoHelper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Combine
import CoreLocation

@MainActor
class BeaconDemoHelper {
    private enum BeaconType {
        case location(loc: GenericLocation, address: String?)
        case entity(id: String, address: String?)
        case ref(id: String)
    }
    
    private struct AudioSystemState {
        let originalBeacon: BeaconType?
        let wasBeaconEnabled: Bool
        let wereBeaconMelodiesDisabled: Bool
        let originalBeaconMelodiesState: Bool
        let wereCalloutsEnabled: Bool
    }
    
    private var shouldRestoreState: Bool = false
    private var systemState: AudioSystemState?
    private var beaconTimer: AnyCancellable?
    
    private var userLocation: CLLocation? {
        return AppContext.shared.geolocationManager.location
    }
    
    private var defaultBeaconLocation: CLLocation? {
        let heading = AppContext.shared.geolocationManager.presentationHeading
        
        guard let location = userLocation, let headingVal = heading.value else {
            return nil
        }
        
        // Calculate beacon location
        return CLLocation(location.coordinate.destination(distance: 100, bearing: headingVal))
    }
    
    /// Sets up the beacon demo by tracking all of the system's current beacon audio state. This allows
    /// for the demo to be configured slightly different from the system's current settings.
    ///
    /// - Parameter disableMelodies: This value overrides the system setting for `SettingsContext.shared.playBeaconStartAndEndMelodies`
    func prepare(disableMelodies: Bool = true) {
        let calloutsEnabled = SettingsContext.shared.automaticCalloutsEnabled
        let beaconMelodiesEnabled = SettingsContext.shared.playBeaconStartAndEndMelodies
        let beaconManager = AppContext.shared.spatialDataContext.destinationManager
        
        var originalBeacon: BeaconType?
        if let destinationID = beaconManager.destinationKey,
           let destinationPOI = beaconManager.destinationPOI(forReferenceID: destinationID) {
            if !beaconManager.destinationIsTemporary(forReferenceID: destinationID) {
                originalBeacon = .ref(id: destinationID)
            } else if let location = destinationPOI as? GenericLocation {
                originalBeacon = .location(loc: location,
                                           address: beaconManager.destinationEstimatedAddress(forReferenceID: destinationID))
            } else {
                originalBeacon = .entity(id: destinationPOI.key,
                                         address: beaconManager.destinationEstimatedAddress(forReferenceID: destinationID))
            }
        }
        
        systemState = AudioSystemState(originalBeacon: originalBeacon,
                                       wasBeaconEnabled: beaconManager.isAudioEnabled,
                                       wereBeaconMelodiesDisabled: disableMelodies,
                                       originalBeaconMelodiesState: beaconMelodiesEnabled,
                                       wereCalloutsEnabled: calloutsEnabled)
        
        AppContext.shared.eventProcessor.hush(playSound: false)
        SettingsContext.shared.automaticCalloutsEnabled = false
        
        if disableMelodies {
            SettingsContext.shared.playBeaconStartAndEndMelodies = false
        }
    }
    
    func play(styleChanged: Bool = false, shouldTimeOut: Bool = true, newBeaconLocation: CLLocation? = nil, logContext: String = "volume_controls.demo") {
        let beaconManager = AppContext.shared.spatialDataContext.destinationManager
        let currentBeaconLocation = newBeaconLocation ?? defaultBeaconLocation
        
        guard beaconTimer == nil else {
            // There is already a demo playing, so just push back the timeout
            beaconTimer?.cancel()
            
            if styleChanged, let beaconLocation = currentBeaconLocation {
                // If the beacon is currently on and the style changed, toggle it off and then back on so that the change in beacon takes place.
                AppContext.shared.eventProcessor.hush(playSound: false)

                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    await self.setDestinationAsync(beaconManager: beaconManager,
                                                   location: beaconLocation,
                                                   address: nil,
                                                   enableAudio: true,
                                                   userLocation: self.userLocation,
                                                   logContext: logContext)
                }
            }
            
            if shouldTimeOut {
                beaconTimer = Timer.publish(every: 8.0, on: RunLoop.main, in: .common)
                    .autoconnect()
                    .first()
                    .sink { [weak self] _ in
                        AppContext.shared.eventProcessor.hush(playSound: false)
                        self?.beaconTimer = nil
                    }
            }
            
            return
        }
        
        // Hush the other possible demo sounds
        AppContext.shared.eventProcessor.hush(playSound: false)
        
        beaconTimer?.cancel()
        
        // Calculate beacon location
        guard let currentBeaconLocation = currentBeaconLocation else {
            return
        }
        
        shouldRestoreState = true

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.setDestinationAsync(beaconManager: beaconManager,
                                           location: currentBeaconLocation,
                                           address: nil,
                                           enableAudio: true,
                                           userLocation: self.userLocation,
                                           logContext: logContext)
        }
        
        if shouldTimeOut {
            beaconTimer = Timer.publish(every: 8.0, on: RunLoop.main, in: .common)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    AppContext.shared.eventProcessor.hush(playSound: false)
                    self?.beaconTimer = nil
                }
        }
    }
    
    func updateBeaconLocation(_ newBeaconLocation: CLLocation) {
        guard let userLocation = userLocation else {
            return
        }
        
        AppContext.shared.spatialDataContext.destinationManager.updateDestinationLocation(newBeaconLocation, userLocation: userLocation)
    }
    
    func restoreState(logContext: String = "volume_controls.demo") {
        beaconTimer?.cancel()
        beaconTimer = nil
        
        guard let systemState = systemState else {
            return
        }
        
        SettingsContext.shared.automaticCalloutsEnabled = systemState.wereCalloutsEnabled
        
        if systemState.wereBeaconMelodiesDisabled {
            SettingsContext.shared.playBeaconStartAndEndMelodies = systemState.originalBeaconMelodiesState
        }
        
        // If a demo hasn't played, we shouldn't attempt to restore the state (no state change occurred)
        guard shouldRestoreState || systemState.wasBeaconEnabled else {
            return
        }
        
        AppContext.shared.eventProcessor.hush(playSound: false)
        
        let beaconManager = AppContext.shared.spatialDataContext.destinationManager
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            try? await beaconManager.clearDestinationAsync(logContext: logContext)

            guard let originalBeacon = systemState.originalBeacon else {
                return
            }

            let user = AppContext.shared.geolocationManager.location
            await self.restoreOriginalBeacon(originalBeacon,
                                             beaconManager: beaconManager,
                                             systemState: systemState,
                                             user: user,
                                             logContext: logContext)
        }
    }

    private func setDestinationAsync(beaconManager: DestinationManagerProtocol,
                                     location: CLLocation,
                                     address: String?,
                                     enableAudio: Bool,
                                     userLocation: CLLocation?,
                                     logContext: String) async {
        let genericLocation = GenericLocation(lat: location.coordinate.latitude,
                                              lon: location.coordinate.longitude)
        _ = try? await beaconManager.setDestinationAsync(location: genericLocation,
                                                         address: address,
                                                         enableAudio: enableAudio,
                                                         userLocation: userLocation,
                                                         logContext: logContext)
    }

    private func restoreOriginalBeacon(_ originalBeacon: BeaconType,
                                       beaconManager: DestinationManagerProtocol,
                                       systemState: AudioSystemState,
                                       user: CLLocation?,
                                       logContext: String) async {
        let restoreContext = logContext + ".restoring_original"

        switch originalBeacon {
        case .location(loc: let loc, address: let address):
            _ = try? await beaconManager.setDestinationAsync(location: loc,
                                                             address: address,
                                                             enableAudio: systemState.wasBeaconEnabled,
                                                             userLocation: user,
                                                             logContext: restoreContext)
        case .entity(id: let id, address: let address):
            _ = try? await beaconManager.setDestinationAsync(entityKey: id,
                                                             enableAudio: systemState.wasBeaconEnabled,
                                                             userLocation: user,
                                                             estimatedAddress: address,
                                                             logContext: restoreContext)
        case .ref(id: let id):
            try? await beaconManager.setDestinationAsync(referenceID: id,
                                                         enableAudio: systemState.wasBeaconEnabled,
                                                         userLocation: user,
                                                         logContext: restoreContext)
        }
    }
}
