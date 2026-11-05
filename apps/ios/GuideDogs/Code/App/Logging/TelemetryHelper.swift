//
//  TelemetryHelper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

private struct UserDefaultKeys {
    static let oobeComplete = "GDATelemetryOOBEComplete"
    static let didWalkWithApp = "GDATelemetryDidWalkWithApp"
    
    static let tutorialBeaconStatus = "GDATelemetryTutorialBeaconStatus"
    static let tutorialMarkerStatus = "GDATelemetryTutorialMarkerStatus"

    static let tutorialBeaconCount = "GDATelemetryTutorialBeaconCount"
    static let tutorialMarkerCount = "GDATelemetryTutorialMarkerCount"
    

    static let beaconCountSet = "GDATelemetryBeaconCountSet"
}

// MARK: -

class TelemetryHelper {
    
    // MARK: Constants
    
    private static let walkingDetectionTimeInterval = TimeInterval(10)
    
    // MARK: Properties

    private let appContext: AppContext
    
    // MARK: Computed Properties

    // MARK: Beacon
    
    /// Possible values: "none", "muted", "unmuted"
    private var beaconState: String {
        if appContext.spatialDataContext.destinationManager.isDestinationSet {
            return appContext.spatialDataContext.destinationManager.isAudioEnabled ? "unmuted" : "muted"
        }
        return "none"
    }
    
    private var connectedDevice: Device? {
        return appContext.deviceManager.devices.first(where: { $0.isConnected })
    }
    
    private var motionActivityTimer: Timer?
    
    // MARK: Headset
    
    /// Possible values: "unpaired", "paired", "connected"
    private var headsetState: String {
        if appContext.deviceManager.devices.isEmpty {
            return "unpaired"
        } else if connectedDevice != nil {
            return "connected"
        }
        return "paired"
    }
    
    // MARK: Initialization

    init(appContext: AppContext) {
        self.appContext = appContext
        
        if !didWalkWithApp {
            // Wait for a motion activity of `walking` and store it in the user defaults
            NotificationCenter.default.addObserver(self, selector: #selector(onMotionActivityDidChange(_:)), name: .motionActivityDidChange, object: nil)
        }
    }
    
    // MARK: Notifications
    
    @objc private func onMotionActivityDidChange(_ notification: Notification) {
        guard let activityType = notification.userInfo?[MotionActivityContext.NotificationKeys.activityType] as? ActivityType else {
            return
        }
        
        if activityType == .walking {
            motionActivityTimer = Timer.scheduledTimer(timeInterval: TelemetryHelper.walkingDetectionTimeInterval,
                                                       target: self,
                                                       selector: #selector(motionActivityTimerFired),
                                                       userInfo: nil,
                                                       repeats: false)
        } else if let motionActivityTimer = motionActivityTimer {
            motionActivityTimer.invalidate()
            self.motionActivityTimer = nil
        }
    }
    
    @objc func motionActivityTimerFired() {
        motionActivityTimer = nil
        didWalkWithApp = true
        NotificationCenter.default.removeObserver(self, name: .motionActivityDidChange, object: nil)
    }
    
}

// MARK: - Snapshots

extension TelemetryHelper {
    
    var deviceSnapshot: [String: String] {
        return [
            "locale": Locale.current.identifier,
            "model": UIDevice.current.modelIdentifier,
            "os.version": UIDevice.current.systemVersion,
            "audio.output": appContext.audioEngine.outputType
        ]
    }
    
    var appSnapshot: [String: String] {
        let settings = SettingsContext.shared
        
        return [
            "version": AppContext.appVersion,
            "build": AppContext.appBuild,
            
            "settings.locale": LocalizationContext.currentAppLocale.identifierHyphened,
            "settings.voice": settings.voiceId ?? "not_set",
            "settings.voice.rate": String(settings.speakingRate),
            "settings.units_of_measure": settings.metricUnits ? "metric" : "imperial",
            "settings.allow_callouts": String(settings.automaticCalloutsEnabled),
            "settings.mix_audio": String(settings.audioSessionMixesWithOthers),
            
            "beacon.style": settings.selectedBeacon,
            "beacon.melodiesEnabled": String(settings.playBeaconStartAndEndMelodies),
            "volume.beacon": String(settings.beaconVolume),
            "volume.tts": String(settings.ttsVolume),
            "volume.other": String(settings.otherVolume),
            
            "tutorial_beacon_status": tutorialBeaconStatus,
            "tutorial_marker_status": tutorialMarkerStatus
        ]
    }
    
    var eventSnapshot: [String: String] {
        var properties = [
            "app.source": BuildSettings.source.rawValue,
            "app.state": AppContext.appState.description,
            "beacon.state": beaconState,
            "ar_headset.state": headsetState,
            "is_flat": String(DeviceMotionManager.shared.isFlat)
        ]
        
        if let connectedDevice = connectedDevice {
            properties["ar_headset.type"] = connectedDevice.type.rawValue
            
            // If this device is a heading provider with an accuracy measure, add it to the telemetry
            if let headingProvider = connectedDevice as? UserHeadingProvider {
                properties["ar_headset.accuracy"] = String(format: "%.02f", headingProvider.accuracy)
            }
        }
        
        return properties
    }
    
    var sessionSnapshot: [String: String] {
        TelemetryContextState.snapshot(app: appSnapshot, device: deviceSnapshot,
                                       accessibility: accessibilityFeatures)
    }

}

// MARK: - User Defaults

extension TelemetryHelper {
    
    private var userDefaults: UserDefaults {
        return UserDefaults.standard
    }
    
    var didWalkWithApp: Bool {
        get {
            return userDefaults.bool(forKey: UserDefaultKeys.didWalkWithApp)
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: UserDefaultKeys.didWalkWithApp)
        }
    }
    
    // MARK: Tutorials

    /// Possible values: "none", "exited", "finished"
    var tutorialMarkerStatus: String {
        get {
            guard let status = userDefaults.string(forKey: UserDefaultKeys.tutorialMarkerStatus) else { return "none" }
            return status
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: UserDefaultKeys.tutorialMarkerStatus)
        }
    }
    
    /// Possible values: "none", "exited", "finished"
    var tutorialBeaconStatus: String {
        get {
            guard let status = userDefaults.string(forKey: UserDefaultKeys.tutorialBeaconStatus) else { return "none" }
            return status
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: UserDefaultKeys.tutorialBeaconStatus)
        }
    }
    
    var tutorialMarkerCount: Int {
        get {
            return userDefaults.integer(forKey: UserDefaultKeys.tutorialMarkerCount)
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: UserDefaultKeys.tutorialMarkerCount)
        }
    }
    
    var tutorialBeaconCount: Int {
        get {
            return userDefaults.integer(forKey: UserDefaultKeys.tutorialBeaconCount)
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: UserDefaultKeys.tutorialBeaconCount)
        }
    }
    
    // MARK: Beacon

    // Used locally to decide whether to show the beacon reminder; never exported.
    var beaconCountSet: Int {
        get {
            return userDefaults.integer(forKey: UserDefaultKeys.beaconCountSet)
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: UserDefaultKeys.beaconCountSet)
        }
    }
    
}

// MARK: - Accessibility

extension TelemetryHelper {
    
    var accessibilityFeatures: [String: String] {
        var accessibilityFeatures = [String: String]()
        
        // Audio
        accessibilityFeatures["voice_over"] = UIAccessibility.isVoiceOverRunning.description
        accessibilityFeatures["mono_audio"] = UIAccessibility.isMonoAudioEnabled.description
        accessibilityFeatures["speak_screen"] = UIAccessibility.isSpeakScreenEnabled.description
        accessibilityFeatures["speak_selection"] = UIAccessibility.isSpeakSelectionEnabled.description

        // Text
        accessibilityFeatures["bold_text"] = UIAccessibility.isBoldTextEnabled.description
        accessibilityFeatures["content_size"] = UIApplication.shared.preferredContentSizeCategory.rawValue

        // Colors
        accessibilityFeatures["grayscale"] = UIAccessibility.isGrayscaleEnabled.description
        accessibilityFeatures["invert_colors"] = UIAccessibility.isInvertColorsEnabled.description
        accessibilityFeatures["darker_system_colors"] = UIAccessibility.isDarkerSystemColorsEnabled.description

        // Other
        accessibilityFeatures["assistive_touch"] = UIAccessibility.isAssistiveTouchRunning.description
        accessibilityFeatures["switch_control"] = UIAccessibility.isSwitchControlRunning.description

        return accessibilityFeatures
    }
    
}

// MARK: -

extension UIApplication.State: CustomStringConvertible {
    public var description: String {
        switch self {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default:
            return "unknown \(self.rawValue)"
        }
    }
}
