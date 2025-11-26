//
//  CalloutStateMachine.swift
//  Soundscape
//
//  This class manages the callout of a list of callouts, one after another,
//  with the ability to hush or restart the whole set of callouts.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation

protocol CalloutStateMachineDelegate: AnyObject {
    func calloutsDidFinish(id: UUID)
}

class CalloutStateMachine {

    // MARK: State Machine

    private enum State {
        case off
        case start
        case playingPrefixSounds
        case stop
        case stopping
        case announcingCallout
        case delayingCalloutAnnounced
        case complete
    }
    
    // MARK: Properties
    
    weak var delegate: CalloutStateMachineDelegate?
    
    private weak var geo: GeolocationManagerProtocol!
    private weak var history: CalloutHistory!
    private weak var motionActivityContext: MotionActivityProtocol!
    private weak var audioEngine: AudioEngineProtocol!
    
    private var state: State = .off
    private var hushed = false
    private var playHushedSound = false
    private var calloutGroup: CalloutGroup?
    private var calloutIterator: IndexingIterator<[CalloutProtocol]>?
    
    private var lastGroupID: UUID?
    
    var currentState: String {
        return String(describing: state)
    }
    
    var isPlaying: Bool {
        return state != .off
    }
    
    // MARK: Initialization
    
    init(audioEngine engine: AudioEngineProtocol,
         geo: GeolocationManagerProtocol,
         motionActivityContext motion: MotionActivityProtocol,
         history calloutHistory: CalloutHistory) {
        history = calloutHistory
        audioEngine = engine
        motionActivityContext = motion
        self.geo = geo
        
        state = .off
    }
    
    // MARK: Methods
    
    func start(_ callouts: CalloutGroup) {
        guard !isPlaying else {
            GDLogVerbose(.stateMachine, "Unable to start callout group. State machine is currently in state: \(String(describing: state))")
            return
        }
        calloutGroup = callouts
        hushed = false
        playHushedSound = false
        
        callouts.onStart?()
        
        GDLogVerbose(.stateMachine, "Entering state: \(State.start)")
        state = .start
        // Stop current sounds if needed
        if callouts.stopSoundsBeforePlaying {
            self.audioEngine.stopDiscrete()
        }
        
        callouts.delegate?.calloutsStarted(for: callouts)
        
        // Prepare the iterator for the callouts
        self.calloutIterator = callouts.callouts.makeIterator()
        
        // Play the sounds indicating that the mode has started
        var sounds: [Sound] = callouts.playModeSounds ? [GlyphSound(.enterMode)] : []
        
        if let prefixSounds = callouts.prefixCallout?.sounds(for: self.geo?.location) {
            sounds.append(contentsOf: prefixSounds.soundArray)
        }
        
        if sounds.count > 0 {
            self.audioEngine.play(Sounds(sounds)) { (success) in
                if self.state == .stopping {
                    GDLogVerbose(.stateMachine, "Callout interrupted. Stopping...")
                    self.complete()
                    callouts.onComplete?(false)
                    return
                }

                if self.state == .off {
                    GDLogVerbose(.stateMachine, "Callouts immediately interrupted. Cleaning up...")
                    callouts.onComplete?(false)
                    return
                }
                
                guard success else {
                    GDLogVerbose(.stateMachine, "Callout did not finish playing successfully. Terminating state machine...")
                    self.complete(failed: true)
                    return
                }
                
                GDLogVerbose(.stateMachine, "Enter mode sound played")
                self.announceCallout()
            }
            
            // Transition to the state to allow mode sounds and prefix sounds to play
            self.state = .playingPrefixSounds
        } else {
            announceCallout()
        }
    }
    
    func hush(playSound: Bool = false) {
        hushed = true
        
        if playSound {
            playHushedSound = true
        }
        stateStop()
    }

    func stop() {
        switch state {
            case .playingPrefixSounds, .announcingCallout:
                stateStop()
            case .complete, .off:
                calloutsDidFinish()
        case .start, .stop, .stopping, .delayingCalloutAnnounced:
            complete()
        }
    }
    
    private func eventDelayCalloutAnnounced() {
        switch state {
            case .announcingCallout:
                stateDelayingCalloutAnnounced()
            case .complete:
                complete()
            case .off:
                calloutsDidFinish()
            case .delayingCalloutAnnounced, .start, .playingPrefixSounds, .stop, .stopping:
                GDLogError(.stateMachine, "Invalid state transition: eventDelayCalloutAnnounced() called from state .\(state)")
        }
    }

    private func eventCalloutAnnounced() {
        switch state{
            case .announcingCallout:
                announceCallout()
            case .delayingCalloutAnnounced:
                announceCallout()      
            case .complete:
                complete()
            case .off:
                calloutsDidFinish()
            case .start, .playingPrefixSounds, .stop, .stopping:
                GDLogError(.stateMachine, "Invalid state transition: eventCalloutAnnounced() called from state .\(state)")
        }
    }

    private func calloutsDidFinish() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.off)")
        state = .off
        if let lastGroupID = self.lastGroupID {
            self.lastGroupID = nil
            Task { @MainActor in
                self.delegate?.calloutsDidFinish(id: lastGroupID)
            }
        }
    }
    
    private func stateStop() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.stop)")
        state = .stop
        
        if self.audioEngine.isDiscreteAudioPlaying {
            // The audio engine is currently playing a discrete sound. Stop it and then move to the .stopping state and wait
            // until the sound is actually stopped (see the completion handlers passed to audioEngine.play() in the .start
            // and .announceCallout states).
            self.audioEngine.stopDiscrete(with: self.hushed && self.playHushedSound ? GlyphSound(.hush) : nil)
            state = .stopping
        } else {
            // In this case, discrete audio isn't currently playing, but we might be between sounds, so still call stopDiscrete in
            // order to clear the sounds queue in the audio engine before moving to the complete state
            self.audioEngine.stopDiscrete(with: self.hushed && self.playHushedSound ? GlyphSound(.hush) : nil)
            complete()
        }
    }
    
    private func announceCallout() {
        guard let calloutGroup = self.calloutGroup else {
            complete(failed: true)
            return
        }
        
        guard let callout = self.calloutIterator?.next() else {
            calloutGroup.onComplete?(true)
            complete()
            return
        }
        
        // If this callout is not within the region to live, skip to the next callout
        if let delegate = calloutGroup.delegate, !delegate.isCalloutWithinRegionToLive(callout) {
            calloutGroup.delegate?.calloutSkipped(callout)
            announceCallout()
            return
        }
        
        calloutGroup.delegate?.calloutStarting(callout)
        self.history?.insert(callout)
        
        let sounds: Sounds
        if let repeatLocation = calloutGroup.repeatingFromLocation {
            sounds = callout.sounds(for: repeatLocation, isRepeat: true)
        } else {
            sounds = callout.sounds(for: self.geo?.location, automotive: self.motionActivityContext.isInVehicle)
        }
        
        self.audioEngine.play(sounds) { (success) in
            calloutGroup.delegate?.calloutFinished(callout, completed: success)
            
            if self.state == .stopping {
                GDLogVerbose(.stateMachine, "Callout interrupted. Stopping...")
                self.complete()
                calloutGroup.onComplete?(false)
                return
            }
            
            if self.state == .off {
                GDLogVerbose(.stateMachine, "Callouts immediately interrupted. Cleaning up...")
                calloutGroup.onComplete?(false)
                return
            }
            
            guard success else {
                GDLogVerbose(.stateMachine, "Callout did not finish playing successfully. Terminating state machine...")
                calloutGroup.onComplete?(false)
                self.complete(failed: true)
                return
            }
            
            self.eventDelayCalloutAnnounced()
        }
        
        CalloutStateMachine.log(callout: callout, context: self.calloutGroup?.logContext)
        
        state = .announcingCallout
    }
    
    private func stateDelayingCalloutAnnounced() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.delayingCalloutAnnounced)")
        state = .delayingCalloutAnnounced
        
        if let delay = self.calloutGroup?.calloutDelay, delay >= 0.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let strongSelf = self, strongSelf.state == .delayingCalloutAnnounced else {
                    return
                }
                
                strongSelf.eventCalloutAnnounced()
            }
        } else {
            announceCallout()
        }
    }
    
    private func complete(failed: Bool = false) {
        GDLogVerbose(.stateMachine, "Entering state: \(State.complete)")
        state = .complete
        
        if !failed && !self.hushed && self.calloutGroup?.playModeSounds == true {
            self.audioEngine.play(GlyphSound(.exitMode)) { (_) in
                GDLogVerbose(.stateMachine, "Exit mode sound played")
                
                self.lastGroupID = self.calloutGroup?.id
                self.calloutIterator = nil
                self.calloutGroup = nil
                self.calloutsDidFinish()
            }
        } else {
            self.lastGroupID = self.calloutGroup?.id
            self.calloutIterator = nil
            self.calloutGroup = nil
            calloutsDidFinish()
        }
    }
    
    class func log(callout: CalloutProtocol, context: String?) {
        var properties = ["type": callout.logCategory,
                          "activity": AppContext.shared.motionActivityContext.currentActivity.rawValue,
                          "audio.output": AppContext.shared.audioEngine.outputType]
        
        if let context =  context {
            properties["context"] = context
        }
        
        GDATelemetry.track("callout", with: properties)
    }
}