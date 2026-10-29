//
//  GDATelemetry.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import UIKit

public class GDATelemetry {
    
    static var helper: TelemetryHelper?
    
    static var debugLog = false

    static let session = TelemetrySession()
    
    private static let controller: TelemetryController = {
        let testing = ProcessInfo.processInfo.arguments.contains("-TESTING") ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SoundscapeTelemetry", isDirectory: true)
        return TelemetryController(enabled: enabled,
            configuration: testing ? nil : TelemetryConfiguration(info: Bundle.main.infoDictionary ?? [:]),
            storage: TelemetryStorage(root: root))
    }()

    private static let consentChanges = NSLock()

    class func initialize() {
        _ = session
        _ = controller
    }

    class var enabled: Bool {
        get { SettingsContext.shared.telemetryEnabled }
        set {
            consentChanges.lock()
            defer { consentChanges.unlock() }
            // Initialize against the old preference before changing consent.
            let pipeline = controller
            if !newValue { pipeline.setEnabled(false) }
            // Do not save renewed consent until revoked storage is gone.
            let enabled = newValue && pipeline.setEnabled(true)
            SettingsContext.shared.telemetryOptout = !enabled
            SettingsContext.shared.telemetryConsentChoiceMade = true
        }
    }

    class func persistInBackground() {
        guard enabled else { return }
        var task: UIBackgroundTaskIdentifier = .invalid
        let finish = {
            if task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
        }
        task = UIApplication.shared.beginBackgroundTask(withName: "Persist telemetry", expirationHandler: finish)
        controller.persist { DispatchQueue.main.async(execute: finish) }
    }

    class func trackScreenView(_ screenName: String, with properties: [String: String]? = nil) {
        var propertiesToSend = properties ?? [:]
        propertiesToSend["screen_name"] = screenName

        track("screen_view", with: propertiesToSend)
    }
    
    class func track(_ eventName: String, value: String) {
        track(eventName, with: ["value": value])
    }
    
    class func track(_ eventName: String, with properties: [String: String]? = nil) {
        guard enabled, controller.collecting else { return }
        let timestamp = Date()
        controller.record {
            let event = TelemetryEvent(name: eventName, timestamp: timestamp, properties: properties ?? [:],
                                       clientID: SettingsContext.shared.clientId, sessionID: session.id,
                                       snapshot: helper?.eventSnapshot ?? [:])
            if debugLog {
                print("[TEL] Event tracked: \(eventName) \(event.attributes)")
            }
            return event
        }
    }
}
