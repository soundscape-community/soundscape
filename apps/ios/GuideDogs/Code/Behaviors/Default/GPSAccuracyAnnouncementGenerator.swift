//
//  GPSAccuracyAnnouncementGenerator.swift
//  GuideDogs
//
//  Created by Ajitesh Bankula on 9/23/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//
//  Description: Generates spoken GPS accuracy announcements based on
//  location updates and app state changes (startup, wake, improved accuracy).
//
import CoreLocation
import Foundation
import Combine


final class GPSAccuracyAnnouncementGenerator: AutomaticGenerator {
    
    //MARK: Dependencies
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
    
    //threadhold for acuracy (meters)
    static let poorAccuracyThreashold: CLLocationAccuracy = 20.0

    private let eventTypes: [StateChangedEvent.Type] = [
        GlyphEvent.self,
        LocationUpdatedEvent.self,
        GPXSimulationStartedEvent.self
    ]
    
    private var currentOpState: OperationState?
    private var previousOpState: OperationState?
    private var cancellables: Set<AnyCancellable> = []
    
    //MARK: initialization
    
    //setus up the listenders and handels settings changes
    init(settings: SettingsContext, motionActivity: MotionActivityProtocol){
        self.settings = settings
        self.motion = motionActivity
        
        //observer for app state changes

        NotificationCenter.default.publisher(for: .appOperationStateDidChange)
             .compactMap { notification -> OperationState? in
                notification.userInfo?[AppContext.Keys.operationState] as? OperationState
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                guard let self = self else { return }
                self.previousOpState = self.currentOpState
                self.currentOpState = newState
                GDLogInfo(.eventProcessor,
                          "GPSAcc: opState changed: \(String(describing: self.previousOpState)) -> \(String(describing: self.currentOpState))")
            }
            .store(in: &cancellables)
        
        //observer for when user enables GPS Accuracy announcemnents
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
    //MARK: Deinit
    deinit{
        cancellables.forEach{
            $0.cancel()
        }
    }
    
    // MARK: Atuomatic Generator Protocal Functions needed
    
    //cancels any pending callouts(not used)
    func cancelCalloutsForEntity(id:String){
        
    }
    
    // this tells us if we shoudl respond to a certain event
    func respondsTo(_ event: StateChangedEvent) -> Bool {
        if settings.gpsAnnouncementsEnabled == false{
            return false
        }
        return eventTypes.contains { $0 == type(of: event) }
    }
    
    
    //handels the valid event types and routes into its cases:
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
    

    // MARK: - First announcement (startup / wake)

    private func handleFirstGPSAnnouncement(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        guard let reason = pending else { return .noAction }
        guard settings.gpsAnnouncementsEnabled else { return .noAction }

        let acc = event.location.horizontalAccuracy
        guard acc.isFinite else { return .noAction }

        let value = LanguageFormatter.string(from: acc)
        let message: String
        if (acc >= 10.0) && (acc <= 20.0) {
            //OK temperature
            let tmpl = GDLocalizedString("gps.accuracy.ok")
            message = String(format: tmpl, value)
            markDone(for: reason)
            pending = nil
        }else if acc > Self.poorAccuracyThreashold {
            // POOR accuracy
            let locale = Locale.autoupdatingCurrent
            var tf = false
            if #available(iOS 16.0, *) {
                if( locale.measurementSystem == .metric){
                    tf = false
                }else{
                    tf = true
                }
            }else{
                if(locale.usesMetricSystem){
                    tf = false
                }else{
                    tf = true
                }
            }
            let tmpl = GDLocalizedString("gps.accuracy.poor")
            if(tf == false){
                message = String(format: tmpl, "meters")
            }else{
                message = String(format: tmpl, "feet")
            }
            pending = .accurate
        } else {
            // GOOD accuracy
            let tmpl = GDLocalizedString("gps.accuracy.good")
            message = String(format: tmpl, value)
            markDone(for: reason)
            pending = nil
        }
        let callout = StringCallout(.system, message)
        return .playCallouts(CalloutGroup([callout], action: .enqueue, logContext: "gps-accuracy"))
    }

    // MARK: -  improvements GPS annoucnement
    private func handleImprovedGPSAnnouncement(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        
        let acc = event.location.horizontalAccuracy
        
        guard acc.isFinite else { return .noAction }
        guard settings.gpsAnnouncementsEnabled else { return .noAction }
        guard acc <= Self.poorAccuracyThreashold, !hasAnnouncedAccurate else { return .noAction }
        
        let value = LanguageFormatter.string(from: acc)
        let message: String
        let tmpl = GDLocalizedString("gps.accuracy.improved","GPS accuracy has improved to about %d feet.")
        
        message = String(format: tmpl, value)
        
        let callout = StringCallout(.system, message, position: 180.0)
        
        markDone(for: .accurate)
        pending = nil
        return .playCallouts(CalloutGroup([callout], action: .enqueue, logContext: "gps-accuracy"))
    }

    
    //marks the appropirate flags once a announcement is made
    private func markDone(for reason: Pending) {
        switch reason {
        case .startup: hasAnnouncedStartup = true
        case .wake:    hasAnnouncedWake = true
        case .accurate: hasAnnouncedAccurate = true
        }
    }

    
}
