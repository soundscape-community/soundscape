//
//  GPSAccuracyAnnouncementGenerator.swift
//  GuideDogs
//
//  Created by Ajitesh Bankula on 9/23/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//
//  Description: Generates spoken GPS accuracy announcements based on
//  location updates and app state changes (startup, wake, improved accuracy).

import Combine
import CoreLocation
import Foundation

final class GPSAccuracyAnnouncementGenerator: AutomaticGenerator {

    // MARK: - Dependencies

    private unowned let settings: SettingsContext
    private unowned let motion: MotionActivityProtocol

    // MARK: - Phase

    /// Tracks what the generator is currently waiting to do.
    ///
    /// - idle:              Nothing pending. No announcements will be made.
    /// - awaitingFirstFix:  Waiting for the first location update after startup or wake.
    /// - awaitingImprovement: A "poor accuracy" announcement was made; waiting for GPS to improve.
    private enum Phase: Equatable {
        case idle
        case awaitingFirstFix(isWake: Bool)
        case awaitingImprovement
    }

    private var phase: Phase = .idle

    // MARK: - Accuracy Tier

    /// Classifies a raw CLLocationAccuracy value into a readable stuff
    ///
    /// Thresholds are in meters (since CoreLocation accuracy based in meters):
    ///   - good:  < 10 m
    ///   - ok:    10 – 20 m
    ///   - poor:  > 20 m
    private enum AccuracyTier {
        case good, ok, poor

        static let okThreshold: CLLocationAccuracy = 10.0
        static let poorThreshold: CLLocationAccuracy = 20.0

        init(accuracy: CLLocationAccuracy) {
            switch accuracy {
            case ..<Self.okThreshold:
                self = .good
            case ..<Self.poorThreshold:
                self = .ok
            default:
                self = .poor
            }
        }
    }
    
    // MARK: - State

    var canInterrupt: Bool = false

    private let eventTypes: [StateChangedEvent.Type] = [
        GlyphEvent.self,
        LocationUpdatedEvent.self,
        GPXSimulationStartedEvent.self
    ]

    private var currentOpState: OperationState?
    private var previousOpState: OperationState?
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Init / Deinit

    init(settings: SettingsContext, motionActivity: MotionActivityProtocol) {
        self.settings = settings
        self.motion = motionActivity

        observeOperationStateChanges()
        observeGPSAnnouncementSettingChanges()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - AutomaticGenerator

    func cancelCalloutsForEntity(id: String) {
        // Not used but it throws error if not there
    }

    func respondsTo(_ event: StateChangedEvent) -> Bool {
        if settings.gpsAnnouncementsEnabled == false {
            return false
        }

        return eventTypes.contains { $0 == type(of: event) }
    }

    func handle(event: StateChangedEvent, verbosity: Verbosity) -> HandledEventAction? {
        if settings.gpsAnnouncementsEnabled == false {
            return .noAction
        }

        switch event {

        case is GPXSimulationStartedEvent:
            GDLogInfo(.eventProcessor, "GPSAccAnn: GPX simulation started -> disabling GPS accuracy announcements")
            phase = .idle
            return .noAction

        case let glyph as GlyphEvent:
            return handleGlyphEvent(glyph)

        case let loc as LocationUpdatedEvent:
            return handleLocationUpdatedEvent(loc)

        default:
            return .noAction
        }
    }

    // MARK: - Event Handlers

    private func handleGlyphEvent(_ glyph: GlyphEvent) -> HandledEventAction? {
        if glyph.glyph != .appLaunch {
            return .noAction
        }

        // Only set a new phase if we are currently idle.
        // This prevents re-announcing if the glyph fires more than once.
        if phase != .idle {
            return .noAction
        }

        let isWake = previousOpState == .sleep || previousOpState == .snooze

        if isWake {
            phase = .awaitingFirstFix(isWake: true)
            GDLogInfo(.eventProcessor, "GPSAccAnn: WAKE -> waiting for LocationUpdatedEvent")
        } else {
            phase = .awaitingFirstFix(isWake: false)
            GDLogInfo(.eventProcessor, "GPSAccAnn: STARTUP -> waiting for LocationUpdatedEvent")
        }

        return .noAction
    }

    private func handleLocationUpdatedEvent(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        if case .awaitingFirstFix = phase {
            return handleFirstFix(event)
        } else if phase == .awaitingImprovement {
            return handleImprovementCheck(event)
        } else {
            return .noAction
        }
    }

    // MARK: - Announcement Logic

    private func handleFirstFix(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        let accuracy = event.location.horizontalAccuracy

        if accuracy.isFinite == false {
            return .noAction
        }

        let message: String
        let tier = AccuracyTier(accuracy: accuracy)

        if tier == .poor {
            let thresholdString = LanguageFormatter.string(from: AccuracyTier.poorThreshold)
            message = String(format: GDLocalizedString("gps.accuracy.poor"), thresholdString)

            // We announced "poor", so now wait until GPS improves.
            phase = .awaitingImprovement

        } else if tier == .ok {
            let accuracyString = LanguageFormatter.string(from: accuracy)
            message = String(format: GDLocalizedString("gps.accuracy.ok"), accuracyString)

            phase = .idle

        } else {
            let accuracyString = LanguageFormatter.string(from: accuracy)
            message = String(format: GDLocalizedString("gps.accuracy.good"), accuracyString)

            phase = .idle
        }

        return makeCallout(message)
    }

    private func handleImprovementCheck(_ event: LocationUpdatedEvent) -> HandledEventAction? {
        let accuracy = event.location.horizontalAccuracy

        if accuracy.isFinite == false {
            return .noAction
        }

        // Only announce improvement once accuracy has reached the poor threshold or better.
        if accuracy > AccuracyTier.poorThreshold {
            return .noAction
        }

        let accuracyString = LanguageFormatter.string(from: accuracy)
        let message = String(format: GDLocalizedString("gps.accuracy.improved"), accuracyString)

        phase = .idle

        return makeCallout(message, position: 180.0)
    }

    // MARK: - Helpers

    /// Wraps a message string into the standard callout + group structure.
    private func makeCallout(_ message: String, position: Double = 0.0) -> HandledEventAction {
        let callout = StringCallout(.system, message, position: position)
        return .playCallouts(CalloutGroup([callout], action: .enqueue, logContext: "gps-accuracy"))
    }

    private func observeOperationStateChanges() {
        NotificationCenter.default.publisher(for: .appOperationStateDidChange)
            .compactMap { $0.userInfo?[AppContext.Keys.operationState] as? OperationState }
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                guard let self = self else { return }

                self.previousOpState = self.currentOpState
                self.currentOpState = newState

                GDLogInfo(
                    .eventProcessor,
                    "GPSAcc: opState changed: \(String(describing: self.previousOpState)) -> \(String(describing: self.currentOpState))"
                )
            }
            .store(in: &cancellables)
    }

    private func observeGPSAnnouncementSettingChanges() {
        NotificationCenter.default.publisher(for: .gpsAnnouncementsEnabledChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }

                let enabledFromNote = note.userInfo?[SettingsContext.Keys.enabled] as? Bool
                let enabled: Bool

                if let value = enabledFromNote {
                    enabled = value
                } else {
                    enabled = self.settings.gpsAnnouncementsEnabled
                }

                GDLogInfo(.eventProcessor, "GPSAccAnn: setting changed -> \(enabled)")

                // Reset to idle in both cases.
                // When disabled, staying idle means no new phases will be entered.
                // When enabled, reset so the next startup/wake triggers fresh announcements.
                self.phase = .idle
            }
            .store(in: &cancellables)
    }
}
