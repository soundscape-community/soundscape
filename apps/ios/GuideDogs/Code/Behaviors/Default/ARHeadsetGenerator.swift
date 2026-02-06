//
//  ARHeadsetGenerator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

class HeadsetConnectionEvent: StateChangedEvent {
    enum State {
        case reconnected, disconnected, firstConnection
    }
    
    var name: String {
        return "HeadsetConnection.\(state).\(headsetName)"
    }
    
    let headsetName: String
    let state: State
    
    init(_ headsetName: String, state: State) {
        self.headsetName = headsetName
        self.state = state
    }
}

class HeadsetCalibrationEvent: StateChangedEvent {
    let headsetName: String
    let deviceType: DeviceType
    let callout: String
    let state: DeviceCalibrationState
    
    init(_ headsetName: String,
         deviceType: DeviceType,
         callout: String,
         state: DeviceCalibrationState) {
        self.headsetName = headsetName
        self.deviceType = deviceType
        self.callout = callout
        self.state = state
    }
}

class CalibrationOverrideEvent: StateChangedEvent { }

extension CalloutOrigin {
    static let arHeadset = CalloutOrigin(rawValue: "ar_headset", localizedString: GDLocalizationUnnecessary("AR HEADSET"))!
}

@MainActor
class ARHeadsetGenerator: AutomaticGenerator, BehaviorEventStreamSubscribing {
    private unowned let audioEngine: AudioEngineProtocol
    private unowned let destinationManager: DestinationManagerProtocol
    private unowned let deviceManager: DeviceManagerProtocol

    private var calibrationPlayerId: AudioPlayerIdentifier?
    
    private var previousCalibrationState = DeviceCalibrationState.needsCalibrating
    
    private var calibrationOverriden = false
    
    /// This property is used for tracking if the audio beacon was enabled before the calibration audio started. If
    /// it was, then the beacon should be toggled back on when the calibration audio is turned off.
    private var previousBeaconAudioEnabled = false
    
    let canInterrupt = false

    init(audioEngine: AudioEngineProtocol, destinationManager: DestinationManagerProtocol, deviceManager: DeviceManagerProtocol) {
        self.audioEngine = audioEngine
        self.destinationManager = destinationManager
        self.deviceManager = deviceManager
    }
    
    func cancelCalloutsForEntity(id: String) {
        // No-op: This generator only responds to events regarding AR headsets and not POIs or locations
    }
    
    func respondsTo(_ event: StateChangedEvent) -> Bool {
        return event is HeadsetConnectionEvent || event is HeadsetCalibrationEvent || event is CalibrationOverrideEvent
    }

    func startEventStreamSubscriptions(userInitiatedEvents: AsyncStream<UserInitiatedEvent>,
                                       stateChangedEvents: AsyncStream<StateChangedEvent>,
                                       delegateProvider: @escaping @MainActor () -> BehaviorDelegate?) -> [Task<Void, Never>] {
        let task = Task { @MainActor in
            for await event in stateChangedEvents {
                if event is CalibrationOverrideEvent {
                    stopCalibrationTrack()
                    calibrationOverriden = true
                }
            }
        }

        return [task]
    }
    
    func handle(event: StateChangedEvent, verbosity: Verbosity) -> HandledEventAction? {
        switch event {
        case let event as HeadsetConnectionEvent:
            // Any connection event will reset the calibration override state
            calibrationOverriden = false
            
            guard let callouts = processConnectionEvent(event) else {
                return nil
            }
            
            return .playCallouts(callouts)
            
        case let event as HeadsetCalibrationEvent:
            guard let callouts = processCalibrationEvent(event) else {
                return nil
            }
            
            return .playCallouts(callouts)
            
        default:
            return nil
        }
    }
    
    private func processConnectionEvent(_ event: HeadsetConnectionEvent) -> CalloutGroup? {
        switch event.state {
        case .firstConnection:
            let earcon = GlyphCallout(.arHeadset, .connectionSuccess)
            return CalloutGroup([earcon], logContext: "ar_headset")
            
        case .reconnected:
            let callout = StringCallout(.arHeadset, GDLocalizedString("devices.callouts.connected", event.headsetName))
            let earcon = GlyphCallout(.arHeadset, .connectionSuccess)
            return CalloutGroup([earcon, callout], logContext: "ar_headset")
            
        case .disconnected:
            previousCalibrationState = .needsCalibrating
            stopCalibrationTrack()
            
            let callout = StringCallout(.arHeadset, GDLocalizedString("devices.callouts.disconnected", event.headsetName))
            let earcon = GlyphCallout(.arHeadset, .invalidFunction)
            return CalloutGroup([earcon, callout], logContext: "ar_headset")
        }
    }
    
    private func processCalibrationEvent(_ event: HeadsetCalibrationEvent) -> CalloutGroup? {
        defer {
            previousCalibrationState = event.state
        }
        
        // Doing this check after defer allows us to still track the calibration state
        guard !calibrationOverriden else {
            if event.state == .calibrated && (previousCalibrationState == .calibrating || previousCalibrationState == .needsCalibrating) {
                return CalloutGroup([GlyphCallout(.arHeadset, .calibrationSuccess)], playModeSounds: false, stopSoundsBeforePlaying: false, logContext: "ar_headset")
            } else {
                return nil
            }
        }
        
        var callouts: CalloutGroup?
        var needsCalibratingCalloutString: String
        
        switch event.deviceType {
        case .boseFramesRondo:
            needsCalibratingCalloutString = GDLocalizedString("devices.callouts.needs_calibration.in_ear")
        default:
            needsCalibratingCalloutString = GDLocalizedString("devices.callouts.needs_calibration")
        }
        
        switch (previousCalibrationState, event.state) {
        case (.needsCalibrating, .calibrating): // Calibration has started
            callouts = CalloutGroup([StringCallout(.arHeadset, needsCalibratingCalloutString)], logContext: "ar_headset")
            callouts?.onStart = self.startCalibrationTrack
            callouts?.isValid = { [weak self] in self?.shouldPlayCalibrationStartedCallouts() ?? false }
            
        case (.calibrating, .calibrated): // Calibration has ended
            let callout = StringCallout(.arHeadset, GDLocalizedString("devices.callouts.calibrated"))
            let earcon = GlyphCallout(.arHeadset, .calibrationSuccess)
            
            callouts = CalloutGroup([earcon, callout], logContext: "ar_headset")
            callouts?.onStart = self.stopCalibrationTrack
            callouts?.isValid = { [weak self] in self?.shouldPlayCalibrationEndCallouts() ?? false }
            
        case (.calibrated, .calibrating): // Device needs to be recalibrated
            let callout = StringCallout(.arHeadset, needsCalibratingCalloutString)
            
            callouts = CalloutGroup([callout], logContext: "ar_headset")
            callouts?.onStart = self.startCalibrationTrack
            callouts?.isValid = { [weak self] in self?.shouldPlayCalibrationStartedCallouts() ?? false }
            
        case (.needsCalibrating, .calibrated): // Device was already calibrated
            let callout = StringCallout(.arHeadset, GDLocalizedString("devices.callouts.calibrated"))
            let earcon = GlyphCallout(.arHeadset, .calibrationSuccess)
            callouts = CalloutGroup([earcon, callout], logContext: "ar_headset")
            callouts?.isValid = { [weak self] in self?.shouldPlayCalibrationEndCallouts() ?? false }
            
        default:
            return nil
        }
        
        return callouts
    }
    
    private func startCalibrationTrack() {
        guard let id = audioEngine.play(looped: GenericSound(.calibrationInProgress)) else {
            return
        }
        
        previousBeaconAudioEnabled = destinationManager.isAudioEnabled
        
        if previousBeaconAudioEnabled {
            destinationManager.toggleDestinationAudio()
        }
        
        calibrationPlayerId = id
    }
    
    private func stopCalibrationTrack() {
        guard let id = calibrationPlayerId else {
            return
        }
        
        if previousBeaconAudioEnabled {
            destinationManager.toggleDestinationAudio()
            previousBeaconAudioEnabled = false
        }
        
        calibrationPlayerId = nil
        audioEngine.stop(id)
    }

    private func shouldPlayCalibrationStartedCallouts() -> Bool {
        guard let device = deviceManager.devices.first as? CalibratableDevice, device.isConnected else { return false }
        return device.calibrationState != .calibrated
    }

    private func shouldPlayCalibrationEndCallouts() -> Bool {
        guard let device = deviceManager.devices.first as? CalibratableDevice, device.isConnected else { return false }
        return device.calibrationState == .calibrated
    }
}
