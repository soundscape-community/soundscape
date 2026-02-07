//
//  HomeViewController+RemoteControl.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

private var isRepeating = false

extension HomeViewController: RemoteCommandManagerDelegate {
    
    func remoteCommandManager(_ remoteCommandManager: RemoteCommandManager, handle event: RemoteCommand) -> Bool {
        GDATelemetry.track("remote_command.\(event.rawValue)")
        let providers = UIRuntimeProviderRegistry.providers
        
        // Disallow remote command events when in sleep/snooze mode
        guard providers.uiIsApplicationInNormalState() else {
            return false
        }
        
        if let route = providers.uiActiveRouteGuidance() {
            switch event {
            case .play, .pause, .stop, .togglePlayPause:
                return providers.uiToggleDestinationAudio(automatic: false)
            case .nextTrack, .seekForward:
                route.nextWaypoint()
                return true
            case .previousTrack, .seekBackward:
                route.previousWaypoint()
                return true
            }
        }
        
        switch event {
        case .play, .pause, .stop, .togglePlayPause:
            return handleToggleAudio()
        case .nextTrack:
            return handleMyLocation()
        case .previousTrack:
            return handleRepeat()
        case .seekForward:
            return handleToggleCallouts()
        case .seekBackward:
            return handleAroundMe()
        }
    }
    
    private func handleToggleAudio() -> Bool {
        UIRuntimeProviderRegistry.providers.uiToggleAudio()
    }
    
    private func handleMyLocation() -> Bool {
        NotificationCenter.default.post(name: Notification.Name.didToggleLocate, object: self)
        return true
    }
    
    private func handleRepeat() -> Bool {
        guard !isRepeating else {
            UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false)
            isRepeating = false
            return true
        }
        
        guard let callout = UIRuntimeProviderRegistry.providers.uiCalloutHistoryCallouts().last else {
            return false
        }
        
        isRepeating = true

        UIRuntimeProviderRegistry.providers.uiProcessEvent(RepeatCalloutEvent(callout: callout) { (_) in
            isRepeating = false
        })
        
        return true
    }
    
    private func handleToggleCallouts() -> Bool {
        UIRuntimeProviderRegistry.providers.uiProcessEvent(ToggleAutoCalloutsEvent(playSound: true))
        
        GDATelemetry.track("settings.allow_callouts", value: String(SettingsContext.shared.automaticCalloutsEnabled))
        
        // Play announcement
        UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false, hushBeacon: false)
        let announcement = SettingsContext.shared.automaticCalloutsEnabled ? GDLocalizedString("callouts.callouts_on") : GDLocalizedString("callouts.callouts_off")
        UIRuntimeProviderRegistry.providers.uiProcessEvent(GenericAnnouncementEvent(announcement))
        return true
    }
    
    private func handleAroundMe() -> Bool {
        NotificationCenter.default.post(name: Notification.Name.didToggleOrientate, object: self)
        return true
    }
}
