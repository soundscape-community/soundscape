//
//  StatusGenerator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation

class CheckAudioEvent: UserInitiatedEvent { }

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

@MainActor
final class SystemGenerator: ManualGenerator {

    private let handledEvents: [UserInitiatedEvent.Type] = [
        CheckAudioEvent.self,
        TTSVoicePreviewEvent.self,
        GenericAnnouncementEvent.self,
        RepeatCalloutEvent.self
    ]

    private unowned let geo: GeolocationManagerProtocol
    private unowned let deviceManager: DeviceManagerProtocol

    init(geo: GeolocationManagerProtocol, device: DeviceManagerProtocol) {
        self.geo = geo
        self.deviceManager = device
    }

    func respondsTo(_ event: UserInitiatedEvent) -> Bool {
        handledEvents.contains { $0 == type(of: event) }
    }

    func handle(event: UserInitiatedEvent,
                verbosity: Verbosity,
                delegate: BehaviorDelegate) async -> [HandledEventAction]? {
        guard let group = calloutGroup(for: event) else {
            return nil
        }

        // Fire-and-forget so user actions can interrupt immediately.
        Task { @MainActor in
            _ = await delegate.playCallouts(group)
        }
        return nil
    }

    private func calloutGroup(for event: UserInitiatedEvent) -> CalloutGroup? {
        switch event {
        case is CheckAudioEvent:
            return makeCheckAudioGroup()

        case let preview as TTSVoicePreviewEvent:
            return makePreviewGroup(preview)

        case let announcement as GenericAnnouncementEvent:
            return makeAnnouncementGroup(announcement)

        case let repeatEvent as RepeatCalloutEvent:
            return makeRepeatGroup(for: repeatEvent)

        default:
            return nil
        }
    }

    private func makeCheckAudioGroup() -> CalloutGroup {
        var callouts: [CalloutProtocol] = []

        guard let device = deviceManager.devices.first else {
            callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.default")))
            return CalloutGroup(callouts, action: .interruptAndClear, logContext: "check_audio")
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
            if boseDevice.isConnected {
                callouts.append(GlyphCallout(.arHeadset, .connectionSuccess))
                callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.bose_frames")))
            } else {
                callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.bose_frames.disconnected")))
            }

        default:
            callouts.append(StringCallout(.arHeadset, GDLocalizedString("devices.callouts.check_audio.default")))
        }

        return CalloutGroup(callouts, action: .interruptAndClear, logContext: "check_audio")
    }

    private func makePreviewGroup(_ event: TTSVoicePreviewEvent) -> CalloutGroup {
        let callout = StringCallout(.system,
                                    GDLocalizedString("voice.apple.preview", event.voiceName),
                                    position: Double.random(in: 0.0 ..< 360.0))
        let group = CalloutGroup([callout], action: .interruptAndClear, logContext: "tts.preview_voice")
        group.onComplete = event.completionHandler
        return group
    }

    private func makeAnnouncementGroup(_ event: GenericAnnouncementEvent) -> CalloutGroup {
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
        return group
    }

    private func makeRepeatGroup(for event: RepeatCalloutEvent) -> CalloutGroup? {
        guard let location = geo.location else {
            return nil
        }

        let group = CalloutGroup([event.callout],
                                 repeatingFromLocation: location,
                                 action: .interruptAndClear,
                                 logContext: "repeat_callout")
        group.onComplete = event.completionHandler
        return group
    }
}
