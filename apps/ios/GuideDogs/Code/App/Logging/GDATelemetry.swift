//
//  GDATelemetry.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import UIKit

public class GDATelemetry {
    
    static var helper: TelemetryHelper?
    
    static var debugLog = false

    static let session = TelemetrySession()
    private static let installationID = TelemetryInstallationID()
    
    private static let controller: TelemetryController = {
        let testing = ProcessInfo.processInfo.arguments.contains("-TESTING") ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SoundscapeTelemetry", isDirectory: true)
        let pipeline = TelemetryController(enabled: enabled,
            configuration: testing ? nil : TelemetryConfiguration(info: Bundle.main.infoDictionary ?? [:]),
            storage: TelemetryStorage(root: root))
        if pipeline.startupPreparationFailed {
            SettingsContext.shared.telemetryOptout = true
        }
        return pipeline
    }()

    // Serialize session rotation, consent, snapshot announcements and event enqueueing.
    private static let eventChanges = NSRecursiveLock()
    private static var context = TelemetryContextState()

    static let contextDidChange = Notification.Name("TelemetryContextDidChange")

    class func snapshotsReady() {
        eventChanges.lock()
        context.ready = true
        captureCachedLocationIfNeeded()
        recordSnapshotIfNeeded()
        eventChanges.unlock()
        NotificationCenter.default.post(name: contextDidChange, object: nil)
    }

    class func operationStateChanged(to state: OperationState) {
        eventChanges.lock()
        let previousID = session.id
        session.operationStateChanged(to: state)
        let rotated = previousID != session.id
        if rotated {
            captureCachedLocationIfNeeded()
            recordSnapshotIfNeeded()
        }
        eventChanges.unlock()
        if rotated { NotificationCenter.default.post(name: contextDidChange, object: nil) }
    }

    private class func captureCachedLocationIfNeeded() {
        guard enabled, controller.collecting, let location = helper?.currentLocation else { return }
        session.captureLocation(location)
    }

    class func locationUpdated(_ location: CLLocation) {
        eventChanges.lock()
        defer { eventChanges.unlock() }
        guard enabled, controller.collecting else { return }
        session.captureLocation(location)
    }

    private class func recordSnapshotIfNeeded() {
        guard let helper = helper,
              context.claimSnapshot(sessionID: session.id, collecting: enabled && controller.collecting) else { return }
        GDATelemetry.track("session.snapshot", with: helper.sessionSnapshot)
    }

    class func trackNaviLensSuggestion() {
        eventChanges.lock()
        defer { eventChanges.unlock() }
        guard context.claimSuggestion(sessionID: session.id, collecting: enabled && controller.collecting,
                                      active: UIApplication.shared.applicationState == .active) else { return }
        GDATelemetry.track("navilens.suggested")
    }

    class func captureOccurrence() -> TelemetryOccurrence? {
        eventChanges.lock()
        defer { eventChanges.unlock() }
        guard enabled, controller.collecting else { return nil }
        recordSnapshotIfNeeded()
        return TelemetryOccurrence(timestamp: Date(), sessionID: session.id,
                                   installationID: session.installationID(using: installationID), consentEpoch: context.consentEpoch, location: session.location, snapshot: helper?.eventSnapshot ?? [:])
    }

    class func initialize() {
        _ = session
        _ = controller
    }

    class var enabled: Bool { SettingsContext.shared.telemetryEnabled }

    class func setConsent(sharingEnabled: Bool) {
        eventChanges.lock()
        // Initialize against the old preference before changing consent.
        let pipeline = controller
        if !sharingEnabled {
            // Persist the choice before scheduling deletion, even if deletion fails.
            SettingsContext.shared.telemetryOptout = true
            SettingsContext.shared.telemetryConsentChoiceMade = true
            pipeline.setEnabled(false)
        }
        // Do not save renewed consent until revoked storage is gone.
        let effectiveEnabled = sharingEnabled && pipeline.setEnabled(true)
        SettingsContext.shared.telemetryOptout = !effectiveEnabled
        SettingsContext.shared.telemetryConsentChoiceMade = true
        if !effectiveEnabled {
            context.revokeConsent()
            session.clearLocation()
        } else {
            captureCachedLocationIfNeeded()
        }
        recordSnapshotIfNeeded()
        eventChanges.unlock()
        NotificationCenter.default.post(name: contextDidChange, object: nil)
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

    class func track(_ eventName: String, value: String) {
        track(eventName, with: ["value": value])
    }
    
    class func track(_ eventName: String, with properties: [String: String]? = nil,
                     occurrence: TelemetryOccurrence? = nil) {
        eventChanges.lock()
        defer { eventChanges.unlock() }
        guard enabled, controller.collecting else { return }
        if let occurrence = occurrence, occurrence.consentEpoch != context.consentEpoch { return }
        recordSnapshotIfNeeded()
        let timestamp = occurrence?.timestamp ?? Date()
        controller.record {
            let event = TelemetryEvent(name: eventName, timestamp: timestamp, properties: properties ?? [:],
                                       clientID: occurrence?.installationID ?? session.installationID(using: installationID),
                                       sessionID: occurrence?.sessionID ?? session.id,
                                       snapshot: occurrence?.snapshot ?? helper?.eventSnapshot ?? [:],
                                       location: occurrence != nil ? occurrence?.location : session.location)
            if debugLog {
                print("[TEL] Event tracked: \(eventName) \(event.attributes)")
            }
            return event
        }
    }
}
