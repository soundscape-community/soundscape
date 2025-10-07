//
//  GPSAccuracyAnnouncementGenerator.swift
//  GuideDogs
//
//  Created by Ajitesh Bankula on 9/23/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

import CoreLocation
import Foundation
import Combine

final class GPSAccuracyAnnouncementGenerator: AutomaticGenerator {
    
    
    private unowned let settings: SettingsContext
    private unowned let motion: MotionActivityProtocol
    private let localeIdentifier: String = Locale.current.identifier
    private var hasAnnouncedStartup = false
    private var hasAnnouncedWake = false
    private var hasAnnouncedAccurate = false
    private enum Pending: Equatable {
        case startup
        case accurate
        case wake
    }
    var canInterrupt: Bool = false

    var first: Bool = true
    
    private var pending: Pending?
    
    //threadhold for acuracy
    static let poorAccuracyThreashold: CLLocationAccuracy = 10.0

    private let eventTypes: [StateChangedEvent.Type] = [
        GlyphEvent.self,
        LocationUpdatedEvent.self,
        GPXSimulationStartedEvent.self
    ]
    
    private var currentOpState: OperationState?
    private var previousOpState: OperationState?
    private var cancellables: Set<AnyCancellable> = []
    
    //init and Deinit
    
    init(settings: SettingsContext, motionActivity: MotionActivityProtocol){
        self.settings = settings
        self.motion = motionActivity
        
        NotificationCenter.default.publisher(for: .appOperationStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                let newState = note.userInfo?[AppContext.Keys.operationState] as? OperationState
                self.previousOpState = self.currentOpState
                self.currentOpState = newState
                GDLogInfo(.eventProcessor, "GPSAcc: opState changed: \(String(describing: self.previousOpState)) -> \(String(describing: self.currentOpState))")
            }
        
        NotificationCenter.default.publisher(for: .gpsAnnouncementsEnabledChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                let enabled = (note.userInfo?[SettingsContext.Keys.enabled] as? Bool) ?? self.settings.gpsAnnouncementsEnabled
                GDLogInfo(.eventProcessor, "GPSAccAnn: setting changed -> \(enabled)")
                if !enabled {
                    self.pending = nil
                    self.hasAnnouncedStartup = true
                    self.hasAnnouncedWake = true
                    self.hasAnnouncedAccurate = true
                } else {
                    self.hasAnnouncedStartup = false
                    self.hasAnnouncedWake = false
                    self.hasAnnouncedAccurate = false
                }
            }
        .store(in: &cancellables)
        
    }
    deinit{
        cancellables.forEach{
            $0.cancel()
        }
    }
    
    // bellow is stuff for Atuomatic Generator Protocal
    func cancelCalloutsForEntity(id:String){
        
    }
    
    // this tells us what type of events we repsond to
    // specificaly for us we are doign when we see a StateChagnedEvent
    func respondsTo(_ event: StateChangedEvent) -> Bool {
        if settings.gpsAnnouncementsEnabled == false{
            return false
        }
        return eventTypes.contains { $0 == type(of: event) }
    }
    
    
    //handels the state changed event and maps into its cases:
    func handle(event: StateChangedEvent, verbosity: Verbosity) -> HandledEventAction? {
        if settings.gpsAnnouncementsEnabled == false{
            return .noAction
        }
        switch event {
            
        // in case we started the GPX simulation we make sure we dont do any anouncement and set to has anounced so we wont
        case is GPXSimulationStartedEvent:
            GDLogInfo(.eventProcessor, "GPX simulation started so n announcements for GPS Accuracy")
            pending = nil
            hasAnnouncedStartup = true
            hasAnnouncedWake = true
            return .noAction

        //decide if we are wakingup or starting up
        case let glyph as GlyphEvent:
            guard glyph.glyph == .appLaunch else { return .noAction }

            
            //wake if:
            let isWake = (previousOpState == .sleep || previousOpState == .snooze)

            if isWake {
                //make sure we havent already anounced
                guard !hasAnnouncedWake else { return .noAction }
                pending = .wake
                GDLogInfo(.eventProcessor, "GPSAccAnn: WAKE waiting for LocationUpdatedEvent")
            } else {
                //make sure we havent already anounced
                guard !hasAnnouncedStartup else { return .noAction }
                pending = .startup
                GDLogInfo(.eventProcessor, "GPSAccAnn: STARTUP waiting for LocationUpdatedEvent")
            }

            return .noAction

        //when we see a locationUpdatedEvent depending on if its first or if its another time since first wasnt acurate chose which helper to launch
        case let loc as LocationUpdatedEvent:
            if pending == .startup || pending == .wake {
                return handleFirstGPSAnnouncement(loc)
            } else if pending == .accurate {
                return handleImprovedGPSAnnouncement(loc)
            } else {
                return .noAction
            }
            
         default:
            return .noAction
            
        }
    }
    
    // if its first time anounceing gps acurac use this
    private func handleFirstGPSAnnouncement(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        guard let reason = pending else { return .noAction }
        if settings.gpsAnnouncementsEnabled == false{
            return .noAction
        }
        let acc = event.location.horizontalAccuracy
        guard acc.isFinite else { return .noAction }

        var message: String


        if acc > Self.poorAccuracyThreashold {
            if localeIdentifier == "en_US" {
                message = "GPS accuracy is poor (±\(Int(acc * 3.28084)) feet). Move around for better accuracy."
                pending = .accurate
            }else{
                message = "GPS accuracy is poor (±\(Int(acc)) meters). Move around for better accuracy."
                pending = .accurate
            }
        } else {
            if localeIdentifier == "en_US" {
                message = "GPS accuracy is good (±\(Int(acc*3.28084)) feet)."
                markDone(for: reason)
                pending = nil
            }else{
                message = "GPS accuracy is good (±\(Int(acc)) meters)."
                markDone(for: reason)
                pending = nil
            }

        }

        let callout = StringCallout(.system, message)
        return .playCallouts(CalloutGroup([callout], action: .enqueue, logContext: "gps-accuracy"))
    }

    // if its second or more time in case we had low gps acuracy use this
    private func handleImprovedGPSAnnouncement(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        let acc = event.location.horizontalAccuracy
        guard acc.isFinite else { return .noAction }
        if settings.gpsAnnouncementsEnabled == false{
            return .noAction
        }
        guard acc <= Self.poorAccuracyThreashold, !hasAnnouncedAccurate else {
            return .noAction
        }
        var message: String
        if localeIdentifier == "en_US" {
            message = "GPS accuracy has improved to \(Int(acc*3.28084)) feet."
            
        }else{
            message = "GPS accuracy has improved to ±\(Int(acc)) meters."
        }
        let callout = StringCallout(.system, message, position: 180.0)


        markDone(for: .accurate)
        pending = nil

        return .playCallouts(CalloutGroup([callout], action: .enqueue, logContext: "gps-accuracy"))
    }

    private func markDone(for reason: Pending) {
        switch reason {
        case .startup: hasAnnouncedStartup = true
        case .wake:    hasAnnouncedWake = true
        case .accurate: hasAnnouncedAccurate = true
        }
    }

    
}



