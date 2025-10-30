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
        case starting
        case stop
        case stopping
        case announceCallout
        case announcingCallout
        case delayingCalloutAnnounced
        case complete
        case failed
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
        eventStart()
    }
    
    func hush(playSound: Bool = false) {
        hushed = true
        
        if playSound {
            playHushedSound = true
        }
        eventHush()
    }

    func stop() {
        eventStop()
    }
    
    // MARK: state machine events

    private func eventStart() {
        switch state {
            case .off:
                stateStart()
            case .start, .starting, .stop, .stopping, .announceCallout, .announcingCallout, .delayingCalloutAnnounced, .complete, .failed:
                GDLogError(.stateMachine, "Invalid state transition: eventStart() called from state .\(state)")
        }
    }

    private func eventStarted() {
        switch state {
            case .starting:
                stateAnnounceCallout()
            case .off, .start, .stop, .stopping, .announceCallout, .announcingCallout, .delayingCalloutAnnounced, .complete, .failed:
                GDLogError(.stateMachine, "Invalid state transition: eventStarted() called from state .\(state)")
        }
    }

    private func eventHush() {
        switch state{
            case .off, .stop, .complete, .failed, .stopping, .starting, .start, .announceCallout, .announcingCallout, .delayingCalloutAnnounced:
                stateStop()
        }
    }
    
    private func eventStop() {
        switch state {
            case .starting, .announcingCallout:
                stateStop()
            case .complete, .off:
                stateOff()
        case .start, .stop, .stopping, .announceCallout, .delayingCalloutAnnounced, .failed:
            stateComplete()
        }
    }
    
    private func eventStopped() {
        switch state {
            case .stopping:
                stateComplete()
            case .announceCallout, .announcingCallout, .complete, .delayingCalloutAnnounced, .failed, .off, .start, .starting, .stop:
                GDLogError(.stateMachine, "Invalid state transition: eventStopped() called from state .\(state)")
        }
    }

    private func eventFailed() {
        switch state {
            case .announceCallout, .announcingCallout, .complete, .delayingCalloutAnnounced, .failed, .off, .start, .starting, .stop, .stopping:
                stateFailed()
        }
    }

    private func eventDelayCalloutAnnounced() {
        switch state {
            case .announcingCallout:
                stateDelayingCalloutAnnounced()
            case .complete:
                stateComplete()
            case .off:
                stateOff()
            case .announceCallout, .delayingCalloutAnnounced, .failed, .start, .starting, .stop, .stopping:
                GDLogError(.stateMachine, "Invalid state transition: eventDelayCalloutAnnounced() called from state .\(state)")
        }
    }

    private func eventCalloutAnnounced() {
        switch state{
            case .announcingCallout:
                stateAnnounceCallout()
            case .delayingCalloutAnnounced:
                stateAnnounceCallout()      
            case .complete:
                stateComplete()
            case .off:
                stateOff()
            case .announceCallout, .failed, .start, .starting, .stop, .stopping:
                GDLogError(.stateMachine, "Invalid state transition: eventCalloutAnnounced() called from state .\(state)")
        }
    }

    private func eventCompleted() {
        switch state {
            case .complete:
                stateOff()
            case .off, .start, .starting, .stop, .stopping, .announceCallout, .announcingCallout, .delayingCalloutAnnounced, .failed:
                GDLogError(.stateMachine, "Invalid state transition: eventCompleted() called from state .\(state)")
        }
    }
}

extension CalloutStateMachine {
    
    private func stateOff() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.off)")
        state = .off
        if let lastGroupID = self.lastGroupID {
            self.lastGroupID = nil
            Task { @MainActor in
                self.delegate?.calloutsDidFinish(id: lastGroupID)
            }
        }
    }
    
    private func stateStart(){
        GDLogVerbose(.stateMachine, "Entering state: \(State.start)")
        state = .start
        guard let calloutGroup = self.calloutGroup else {
            self.eventFailed()
            return
        }
        
        // Stop current sounds if needed
        if calloutGroup.stopSoundsBeforePlaying {
            self.audioEngine.stopDiscrete()
        }
        
        calloutGroup.delegate?.calloutsStarted(for: calloutGroup)
        
        // Prepare the iterator for the callouts
        self.calloutIterator = calloutGroup.callouts.makeIterator()
        
        // Play the sounds indicating that the mode has started
        var sounds: [Sound] = calloutGroup.playModeSounds ? [GlyphSound(.enterMode)] : []
        
        if let prefixSounds = calloutGroup.prefixCallout?.sounds(for: self.geo?.location) {
            sounds.append(contentsOf: prefixSounds.soundArray)
        }
        
        if sounds.count > 0 {
            self.audioEngine.play(Sounds(sounds)) { (success) in
                guard self.state != .stopping else {
                    GDLogVerbose(.stateMachine, "Callout interrupted. Stopping...")
                    self.eventStopped()
                    calloutGroup.onComplete?(false)
                    return
                }
                
                guard self.state != .off else {
                    GDLogVerbose(.stateMachine, "Callouts immediately interrupted. Cleaning up...")
                    calloutGroup.onComplete?(false)
                    return
                }
                
                guard success else {
                    GDLogVerbose(.stateMachine, "Callout did not finish playing successfully. Terminating state machine...")
                    self.eventFailed()
                    return
                }
                
                GDLogVerbose(.stateMachine, "Enter mode sound played")
                self.eventStarted()
            }
            
            // Transition to the state to allow mode sounds and prefix sounds to play
            // fixme: this should use events to transition state but copying original behaviour exactly for now
            self.stateStarting()
        } else {
            // Transition to the state to announce callouts
            // fixme: this should use events to transition state but copying original behaviour exactly for now
            stateAnnounceCallout()
        }
    }
    
    private func stateStarting() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.starting)")
        state = .starting
    }
    
    private func stateStop() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.stop)")
        state = .stop
        
        if self.audioEngine.isDiscreteAudioPlaying {
            // The audio engine is currently playing a discrete sound. Stop it and then move to the .stopping state and wait
            // until the sound is actually stopped (see the completion handlers passed to audioEngine.play() in the .start
            // and .announceCallout states).
            self.audioEngine.stopDiscrete(with: self.hushed && self.playHushedSound ? GlyphSound(.hush) : nil)
            // fixme
            stateStopping()
        } else {
            // In this case, discrete audio isn't currently playing, but we might be between sounds, so still call stopDiscrete in
            // order to clear the sounds queue in the audio engine before moving to the complete state
            self.audioEngine.stopDiscrete(with: self.hushed && self.playHushedSound ? GlyphSound(.hush) : nil)
            //fixme
            stateComplete()
        }
    }
    
    private func stateStopping() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.stopping)")
        state = .stopping
    }
    
    private func stateAnnounceCallout() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.announceCallout)")
        state = .announceCallout
        
        guard let calloutGroup = self.calloutGroup else {
            eventFailed()
            return
        }
        
        guard let callout = self.calloutIterator?.next() else {
            calloutGroup.onComplete?(true)
            //fixme
            stateComplete()
            return
        }
        
        // If this callout is not within the region to live, skip to the next callout
        if let delegate = calloutGroup.delegate, !delegate.isCalloutWithinRegionToLive(callout) {
            calloutGroup.delegate?.calloutSkipped(callout)
            //fixme
            stateAnnounceCallout()
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
            
            guard self.state != .stopping else {
                GDLogVerbose(.stateMachine, "Callout interrupted. Stopping...")
                self.eventStopped()
                calloutGroup.onComplete?(false)
                return
            }
            
            guard self.state != .off else {
                GDLogVerbose(.stateMachine, "Callouts immediately interrupted. Cleaning up...")
                calloutGroup.onComplete?(false)
                return
            }
            
            guard success else {
                GDLogVerbose(.stateMachine, "Callout did not finish playing successfully. Terminating state machine...")
                calloutGroup.onComplete?(false)
                self.eventFailed()
                return
            }
            
            self.eventDelayCalloutAnnounced()
        }
        
        CalloutStateMachineLogger.log(callout: callout, context: self.calloutGroup?.logContext)
        
        //fixme
        stateAnnouncingCallout()
    }
    
    private func stateAnnouncingCallout() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.announcingCallout)")
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
            //fixme
            stateAnnounceCallout()
        }
    }
    
    private func stateComplete() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.complete)")
        state = .complete
        
        if !self.hushed && self.calloutGroup?.playModeSounds ?? false {
            self.audioEngine.play(GlyphSound(.exitMode)) { (_) in
                GDLogVerbose(.stateMachine, "Exit mode sound played")
                
                self.lastGroupID = self.calloutGroup?.id
                self.calloutIterator = nil
                self.calloutGroup = nil
                self.eventCompleted()
            }
        } else {
            self.lastGroupID = self.calloutGroup?.id
            self.calloutIterator = nil
            self.calloutGroup = nil
            //fixme
            stateOff()
        }
    }
    
    /// This is the same as COMPLETE except no additional sounds may be played
    private func stateFailed() {
        GDLogVerbose(.stateMachine, "Entering state: \(State.failed)")
        state = .failed
        
        
        self.lastGroupID = self.calloutGroup?.id
        self.calloutIterator = nil
        self.calloutGroup = nil
        //fixme
        stateOff()
    }
    
}

private class CalloutStateMachineLogger {
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
