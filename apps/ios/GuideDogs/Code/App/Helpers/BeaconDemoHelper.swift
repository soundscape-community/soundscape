//
//  BeaconDemoHelper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Combine
import CoreLocation

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
    private var previewDestinationKey: String?
    
    private let beaconManager: DestinationManagerProtocol
    private let currentLocation: () -> CLLocation?

    init(destinationManager: DestinationManagerProtocol = AppContext.shared.spatialDataContext.destinationManager,
         userLocation: @escaping () -> CLLocation? = { AppContext.shared.geolocationManager.location }) {
        beaconManager = destinationManager
        currentLocation = userLocation
    }

    private var userLocation: CLLocation? { currentLocation() }

    private func hush() {
        if beaconManager.destinationKey == previewDestinationKey, beaconManager.isAudioEnabled {
            beaconManager.toggleDestinationAudio()
        }
        AppContext.shared.eventProcessor.hush(playSound: false, hushBeacon: false)
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
        guard systemState == nil else { return }
        let calloutsEnabled = SettingsContext.shared.automaticCalloutsEnabled
        let beaconMelodiesEnabled = SettingsContext.shared.playBeaconStartAndEndMelodies
        
        var originalBeacon: BeaconType?
        if let ref = beaconManager.destination {
            if !ref.isTemp {
                originalBeacon = .ref(id: ref.id)
            } else {
                let poi = ref.getPOI()
                
                if let loc = poi as? GenericLocation {
                    originalBeacon = .location(loc: loc, address: ref.estimatedAddress)
                } else {
                    originalBeacon = .entity(id: poi.key, address: ref.estimatedAddress)
                }
            }
        }
        
        systemState = AudioSystemState(originalBeacon: originalBeacon,
                                       wasBeaconEnabled: beaconManager.isAudioEnabled,
                                       wereBeaconMelodiesDisabled: disableMelodies,
                                       originalBeaconMelodiesState: beaconMelodiesEnabled,
                                       wereCalloutsEnabled: calloutsEnabled)
        previewDestinationKey = beaconManager.destinationKey
        
        (beaconManager as? DestinationManager)?.beginBeaconDemo()
        hush()
        SettingsContext.shared.automaticCalloutsEnabled = false
        
        if disableMelodies {
            SettingsContext.shared.playBeaconStartAndEndMelodies = false
        }
    }
    
    func play(styleChanged: Bool = false, shouldTimeOut: Bool = true, newBeaconLocation: CLLocation? = nil, logContext: String = "volume_controls.demo") {
        // Navigation may have replaced or removed the destination while settings were open.
        guard systemState != nil, beaconManager.destinationKey == previewDestinationKey else { return }
        let currentBeaconLocation = newBeaconLocation ?? defaultBeaconLocation
        
        guard beaconTimer == nil else {
            // There is already a demo playing, so just push back the timeout
            beaconTimer?.cancel()
            
            if styleChanged, let beaconLocation = currentBeaconLocation {
                // If the beacon is currently on and the style changed, toggle it off and then back on so that the change in beacon takes place.
                hush()
                
                _ = try? beaconManager.setDestination(location: beaconLocation,
                                                      address: nil,
                                                      enableAudio: true,
                                                      userLocation: userLocation,
                                                      logContext: logContext)
                previewDestinationKey = beaconManager.destinationKey
            }
            
            if shouldTimeOut {
                beaconTimer = Timer.publish(every: 8.0, on: RunLoop.main, in: .common)
                    .autoconnect()
                    .first()
                    .sink { [weak self] _ in
                        self?.hush()
                        self?.beaconTimer = nil
                    }
            }
            
            return
        }
        
        // Hush the other possible demo sounds
        hush()
        
        beaconTimer?.cancel()
        
        // Calculate beacon location
        guard let currentBeaconLocation = currentBeaconLocation else {
            return
        }
        
        shouldRestoreState = true
        
        _ = try? beaconManager.setDestination(location: currentBeaconLocation,
                                              address: nil,
                                              enableAudio: true,
                                              userLocation: userLocation,
                                              logContext: logContext)
        previewDestinationKey = beaconManager.destinationKey
        
        if shouldTimeOut {
            beaconTimer = Timer.publish(every: 8.0, on: RunLoop.main, in: .common)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    self?.hush()
                    self?.beaconTimer = nil
                }
        }
    }
    
    func updateBeaconLocation(_ newBeaconLocation: CLLocation) {
        guard beaconManager.destinationKey == previewDestinationKey, let userLocation = userLocation else {
            return
        }
        
        beaconManager.updateDestinationLocation(newBeaconLocation, userLocation: userLocation)
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
        
        var restoredOriginal = false
        defer {
            (beaconManager as? DestinationManager)?.endBeaconDemo(restoreAudio: restoredOriginal, userLocation: userLocation)
            self.systemState = nil
            shouldRestoreState = false
            previewDestinationKey = nil
        }

        // Restore only the destination this session still owns, never a later navigation choice.
        guard beaconManager.destinationKey == previewDestinationKey else { return }

        // No replacement is needed when the original beacon was already silent.
        guard shouldRestoreState || systemState.wasBeaconEnabled else {
            restoredOriginal = systemState.originalBeacon != nil
            return
        }

        hush()
        do {
            try beaconManager.clearDestination(logContext: logContext)
            guard let originalBeacon = systemState.originalBeacon else { return }

            // Restore the destination silently, then let the manager reconcile current arrival,
            // temporary suppression and any setting changes made while the demo was open.
            let user = userLocation
            switch originalBeacon {
            case .location(loc: let loc, address: let address):
                try beaconManager.setDestination(location: loc, address: address, enableAudio: false,
                                                 userLocation: user, logContext: logContext + ".restoring_original")
            case .entity(id: let id, address: let address):
                try beaconManager.setDestination(entityKey: id, enableAudio: false, userLocation: user,
                                                 estimatedAddress: address, logContext: logContext + ".restoring_original")
            case .ref(id: let id):
                try beaconManager.setDestination(referenceID: id, enableAudio: false,
                                                 userLocation: user, logContext: logContext + ".restoring_original")
            }
            restoredOriginal = true
        } catch {
            GDLogAppError("Unable to restore beacon after demo: \(error)")
        }
    }
}
