//
//  StatusGenerator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//
import CoreLocation

class CheckAudioEvent: UserInitiatedEvent { }

class AnnounceGPSAccuracyEvent: UserInitiatedEvent { }

class TTSVoicePreviewEvent: UserInitiatedEvent {
    var voiceName: String
    
    let completionHandler: ((Bool) -> Void)?
    
    init(name: String, completionHandler: ((Bool) -> Void)? = nil) {
        self.voiceName = name
        self.completionHandler = completionHandler
    }
}

struct RepeatCalloutEvent: UserInitiatedEvent {
    let callout: CalloutProtocol
    let completionHandler: ((Bool) -> Void)?
}

class GenericAnnouncementEvent: UserInitiatedEvent {
    let glyph: StaticAudioEngineAsset?
    let announcement: String
    
    let completionHandler: ((Bool) -> Void)?
    
    let compass: CLLocationDirection?
    let direction: CLLocationDirection?
    let location: CLLocation?
    
    private init(_ announcement: String,
                 glyph: StaticAudioEngineAsset? = nil,
                 compass: CLLocationDirection?,
                 direction: CLLocationDirection?,
                 location: CLLocation?,
                 completionHandler: ((Bool) -> Void)? = nil) {
        self.glyph = glyph
        self.announcement = announcement
        self.compass = compass
        self.direction = direction
        self.location = location
        self.completionHandler = completionHandler
    }
    
    convenience init(_ announcement: String, glyph: StaticAudioEngineAsset? = nil, completionHandler: ((Bool) -> Void)? = nil) {
        self.init(announcement, glyph: glyph, compass: nil, direction: nil, location: nil, completionHandler: completionHandler)
    }
    
    convenience init(_ announcement: String, glyph: StaticAudioEngineAsset? = nil, compass: CLLocationDirection, completionHandler: ((Bool) -> Void)? = nil) {
        self.init(announcement, glyph: glyph, compass: compass, direction: nil, location: nil, completionHandler: completionHandler)
    }
    
    convenience init(_ announcement: String, glyph: StaticAudioEngineAsset? = nil, direction: CLLocationDirection, completionHandler: ((Bool) -> Void)? = nil) {
        self.init(announcement, glyph: glyph, compass: nil, direction: direction, location: nil, completionHandler: completionHandler)
    }
    
    convenience init(_ announcement: String, glyph: StaticAudioEngineAsset? = nil, location: CLLocation, completionHandler: ((Bool) -> Void)? = nil) {
        self.init(announcement, glyph: glyph, compass: nil, direction: nil, location: location, completionHandler: completionHandler)
    }
}

class SystemGenerator: ManualGenerator {
    
    private var eventTypes: [Event.Type] = [
        CheckAudioEvent.self,
        TTSVoicePreviewEvent.self,
        GenericAnnouncementEvent.self,
        RepeatCalloutEvent.self,
        AnnounceGPSAccuracyEvent.self
    ]
    
    private unowned let geo: GeolocationManagerProtocol
    private unowned let deviceManager: DeviceManagerProtocol
    
    init(geo: GeolocationManagerProtocol, device: DeviceManagerProtocol) {
        self.geo = geo
        self.deviceManager = device
    }
    
    func respondsTo(_ event: UserInitiatedEvent) -> Bool {
        return eventTypes.contains { $0 == type(of: event) }
    }
    
    func handle(event: UserInitiatedEvent, verbosity: Verbosity) -> HandledEventAction? {
        switch event {
        case is CheckAudioEvent:
            var callouts: [CalloutProtocol] = []
            
            guard let device = deviceManager.devices.first else {
                callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.default")))
                return .playCallouts(CalloutGroup(callouts, action: .interruptAndClear, logContext: "check_audio"))
            }
            
            switch device {
            case let headphoneMotionManager as HeadphoneMotionManagerWrapper:
                if headphoneMotionManager.isConnected {
                    callouts.append(GlyphCallout(.arHeadset, .connectionSuccess))
                    callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.airpods")))
                } else {
                    callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.airpods.disconnected")))
                }
            case let boseDevice as BoseFramesMotionManager:
                if(boseDevice.isConnected) {
                    callouts.append(GlyphCallout(.arHeadset, .connectionSuccess))
                    callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.bose_frames")))
                } else {
                    callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.bose_frames.disconnected"))) //"devices.callouts.check_audio.airpods.disconnected")))
                }
                
            default:
                callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.default")))
            }
            
            return .playCallouts(CalloutGroup(callouts, action: .interruptAndClear, logContext: "check_audio"))
            
        case let event as TTSVoicePreviewEvent:
            let callout = StringCallout(.system, GDLocalizedString("voice.apple.preview", event.voiceName), position: Double.random(in: 0.0 ..< 360.0))
            let group = CalloutGroup([callout], action: .interruptAndClear, logContext: "tts.preview_voice")
            group.onComplete = event.completionHandler
            
            return .playCallouts(group)
            
        case let event as GenericAnnouncementEvent:
            let callout: StringCallout
            
            if let compass = event.compass {
                callout = StringCallout(.system, event.announcement, glyph: event.glyph, position: compass)
            } else if let direction = event.direction {
                callout = RelativeStringCallout(.system, event.announcement, glyph: event.glyph, position: direction)
            } else if let location = event.location {
                callout = StringCallout(.system, event.announcement, glyph: event.glyph, location: location)
            } else {
                callout = StringCallout(.system, event.announcement, glyph: event.glyph)
            }
            
            let group = CalloutGroup([callout], action: .interruptAndClear, logContext: "system_announcement")
            group.onComplete = event.completionHandler
            
            return .playCallouts(group)
            
        case let event as RepeatCalloutEvent:
            guard let location = geo.location else {
                return nil
            }
            
            return .playCallouts(CalloutGroup([event.callout], repeatingFromLocation: location, action: .interruptAndClear, logContext: "repeat_callout"))
        case is AnnounceGPSAccuracyEvent:
            guard let loc = geo.location else {
                let msg = GDLocalizedString("gps.accuracy.unavailable", "GPS accuracy unavailable.")
                let callout = StringCallout(.system, msg)
                return .playCallouts(CalloutGroup([callout],
                                                  action: .interruptAndClear,
                                                  logContext: "gps-accuracy.manual"))
            }
            
            // Validate coordinates
            guard CLLocationCoordinate2DIsValid(loc.coordinate) else {
                let msg = GDLocalizedString("gps.accuracy.unavailable", "GPS accuracy unavailable.")
                let callout = StringCallout(.system, msg)
                return .playCallouts(CalloutGroup([callout],
                                                  action: .interruptAndClear,
                                                  logContext: "gps-accuracy.manual"))
            }
            
            // Validate accuracy
            let acc = loc.horizontalAccuracy
            guard acc.isFinite, acc >= 0 else {
                let msg = GDLocalizedString("gps.accuracy.unavailable", "GPS accuracy unavailable.")
                let callout = StringCallout(.system, msg)
                return .playCallouts(CalloutGroup([callout],action: .interruptAndClear,logContext: "gps-accuracy.manual"))
            }
            
            let localeIdentifier = Locale.current.identifier
            let message: String
            if usesImperialUnits(localeIdentifier) {
                let feet = Int(acc.rounded()*3.28084)
                let template = GDLocalizedString("gps.accuracy.announce.feet", "GPS accuracy is ±{value} feet.")
                message = template.replacingOccurrences(of: "%@", with: "\(feet)")
            } else {
                let meters = Int(acc.rounded())
                let template = GDLocalizedString("gps.accuracy.announce.meters", "GPS accuracy is ±%d meters.")
                message = String(format: template, meters)
            }
            
            
            let callout = StringCallout(.system, message, position: 180.0)
            return .playCallouts(CalloutGroup([callout], action: .interruptAndClear, logContext: "gps-accuracy.manual"))
        default:
            return nil
        }
    }
    
    // --- Only new code below (helper mirrors previous file’s approach) ---
    
    private func usesImperialUnits(_ localeIdentifier: String) -> Bool {
        // Updated to rely on system measurement settings rather than localeIdentifier.
        // (localeIdentifier retained to avoid signature changes)
        _ = localeIdentifier
        let locale = Locale.autoupdatingCurrent
        if #available(iOS 16.0, *) {
            let ms = locale.measurementSystem
            if ms == .us { return true }
            if ms == .uk { return false }      // change to `true` if you want UK treated as imperial
            if ms == .metric { return false }
            // Future/unknown cases: fallback to legacy heuristic
            return !locale.usesMetricSystem
        } else {
            if let region = locale.regionCode, ["US", "LR", "MM"].contains(region) {
                return true
            }
            return !locale.usesMetricSystem
        }
    }
}
