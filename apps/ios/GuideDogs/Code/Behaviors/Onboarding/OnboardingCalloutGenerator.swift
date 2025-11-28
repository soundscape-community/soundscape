//
//  OnboardingCalloutGenerator.swift
//  Soundscape
//
//  Async manual generator that centralizes onboarding callout sequencing
//  so the behavior no longer needs to inline delegate interactions.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation

@MainActor
final class OnboardingCalloutGenerator: AsyncManualGenerator {

    private let handledEvents: [UserInitiatedEvent.Type] = [
        OnboardingExampleCalloutEvent.self,
        SelectedBeaconCalloutEvent.self,
        SelectedBeaconOrientationCalloutEvent.self
    ]

    func respondsTo(_ event: UserInitiatedEvent) -> Bool {
        handledEvents.contains { $0 == type(of: event) }
    }

    func handleAsync(event: UserInitiatedEvent,
                     verbosity: Verbosity,
                     delegate: BehaviorDelegate) async -> [HandledEventAction]? {
        switch event {
        case let example as OnboardingExampleCalloutEvent:
            let group = makeExampleCallouts(completion: example.completion)
            _ = await delegate.playCallouts(group)
            return nil

        case let selected as SelectedBeaconCalloutEvent:
            guard let group = makeBeaconCallouts(completion: selected.completion) else {
                selected.completion?(false)
                return nil
            }

            _ = await delegate.playCallouts(group)
            return nil

        case let orientation as SelectedBeaconOrientationCalloutEvent:
            guard let group = makeBeaconOrientationCallouts(isAhead: orientation.isAhead) else {
                return nil
            }

            _ = await delegate.playCallouts(group)
            return nil

        default:
            return nil
        }
    }

    private func makeExampleCallouts(completion: ((Bool) -> Void)?) -> CalloutGroup {
        let callouts: [CalloutProtocol] = [
            GlyphCallout(.onboarding, .enterMode),
            RelativeGlyphCallout(.onboarding, .poiSense, position: 90.0),
            RelativeStringCallout(.onboarding, GDLocalizedString("first_launch.callouts.example.1"), position: 90.0),
            RelativeGlyphCallout(.onboarding, .poiSense, position: 270.0),
            RelativeStringCallout(.onboarding, GDLocalizedString("osm.tag.bus_stop"), position: 270.0),
            RelativeGlyphCallout(.onboarding, .mobilitySense, position: 0.0),
            RelativeStringCallout(.onboarding, GDLocalizedString("preview.approaching_intersection.label"), position: 0.0),
            RelativeStringCallout(.onboarding, GDLocalizedString("first_launch.callouts.example.3"), position: 270.0),
            RelativeStringCallout(.onboarding, GDLocalizedString("first_launch.callouts.example.4"), position: 90.0),
            GlyphCallout(.onboarding, .exitMode)
        ]

        let group = CalloutGroup(callouts, logContext: "onboarding.callouts")
        group.onComplete = completion
        return group
    }

    private func makeBeaconCallouts(completion: ((Bool) -> Void)?) -> CalloutGroup? {
        guard let beacon = BeaconOption(id: SettingsContext.shared.selectedBeacon) else {
            return nil
        }

        guard let marker = AppContext.shared.spatialDataContext.destinationManager.destination else {
            return nil
        }

        guard !FirstUseExperience.didComplete(.oobeSelectBeacon(style: beacon.style)) else {
            return nil
        }

        FirstUseExperience.setDidComplete(for: .oobeSelectBeacon(style: beacon.style))

        let callouts: [CalloutProtocol] = [GenericCallout(.onboarding, soundsBuilder: { location, _, _ in
            guard let location = location else {
                return []
            }

            let localizedString: String

            switch beacon.style {
            case .standard: localizedString = GDLocalizedString("first_launch.beacon.callout.headtracking.standard")
            case .haptic: localizedString = GDLocalizedString("first_launch.beacon.callout.headtracking.haptic")
            }

            return [TTSSound(localizedString, at: marker.closestLocation(from: location))]
        })]

        let group = CalloutGroup(callouts, logContext: "onboarding.beacon.first_selection")
        group.onComplete = completion
        return group
    }

    private func makeBeaconOrientationCallouts(isAhead: Bool) -> CalloutGroup? {
        guard let beacon = BeaconOption(id: SettingsContext.shared.selectedBeacon) else {
            return nil
        }

        guard beacon.isOrientationCalloutsEnabled(isAhead: isAhead) else {
            return nil
        }

        guard let marker = AppContext.shared.spatialDataContext.destinationManager.destination else {
            return nil
        }

        let callouts: [CalloutProtocol] = [GenericCallout(.onboarding, soundsBuilder: { location, _, _ in
            guard let location = location else {
                return []
            }

            let localizedString = isAhead ? GDLocalizedString("first_launch.beacon.callout.ahead") : GDLocalizedString("first_launch.beacon.callout.behind")
            return [TTSSound(localizedString, at: marker.closestLocation(from: location))]
        })]

        return CalloutGroup(callouts, action: .clear, logContext: "onboarding.beacon.orientation")
    }
}

private extension BeaconOption {
    func isOrientationCalloutsEnabled(isAhead: Bool) -> Bool {
        if isAhead {
            return true
        } else {
            switch self {
            case .original, .tacticle, .flare:
                return true
            case .pulse:
                return false
            default:
                return false
            }
        }
    }
}
