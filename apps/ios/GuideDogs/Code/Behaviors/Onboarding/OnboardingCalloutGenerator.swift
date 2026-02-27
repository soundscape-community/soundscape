//
//  OnboardingCalloutGenerator.swift
//  Soundscape
//
//  Async manual generator that centralizes onboarding callout sequencing
//  so the behavior no longer needs to inline delegate interactions.
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation

@MainActor
final class OnboardingCalloutGenerator: ManualGenerator {

    private let handledEvents: [UserInitiatedEvent.Type] = [
        OnboardingExampleCalloutEvent.self,
        SelectedBeaconCalloutEvent.self,
        SelectedBeaconOrientationCalloutEvent.self
    ]

    func respondsTo(_ event: UserInitiatedEvent) -> Bool {
        handledEvents.contains { $0 == type(of: event) }
    }

    func handle(event: UserInitiatedEvent,
                verbosity: Verbosity,
                delegate: BehaviorDelegate) async -> [HandledEventAction]? {
        switch event {
        case let example as OnboardingExampleCalloutEvent:
            let group = makeExampleCallouts(completion: example.completion)
            _ = await delegate.playCallouts(group)
            return nil

        case let selected as SelectedBeaconCalloutEvent:
            guard let group = await makeBeaconCallouts(destinationPOI: selected.destinationPOI,
                                                       completion: selected.completion) else {
                selected.completion?(false)
                return nil
            }

            _ = await delegate.playCallouts(group)
            return nil

        case let orientation as SelectedBeaconOrientationCalloutEvent:
            guard let group = await makeBeaconOrientationCallouts(isAhead: orientation.isAhead,
                                                                  destinationPOI: orientation.destinationPOI) else {
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

    private func makeBeaconCallouts(destinationPOI: POI?,
                                    completion: ((Bool) -> Void)?) async -> CalloutGroup? {
        guard let beacon = BeaconOption(id: SettingsContext.shared.selectedBeacon) else {
            return nil
        }

        guard let destinationPOI = await destinationPOIForCurrentDestination(destinationPOI: destinationPOI) else {
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

            return [TTSSound(localizedString, at: destinationPOI.closestLocation(from: location))]
        })]

        let group = CalloutGroup(callouts, logContext: "onboarding.beacon.first_selection")
        group.onComplete = completion
        return group
    }

    private func makeBeaconOrientationCallouts(isAhead: Bool,
                                               destinationPOI: POI?) async -> CalloutGroup? {
        guard let beacon = BeaconOption(id: SettingsContext.shared.selectedBeacon) else {
            return nil
        }

        guard beacon.isOrientationCalloutsEnabled(isAhead: isAhead) else {
            return nil
        }

        guard let destinationPOI = await destinationPOIForCurrentDestination(destinationPOI: destinationPOI) else {
            return nil
        }

        let callouts: [CalloutProtocol] = [GenericCallout(.onboarding, soundsBuilder: { location, _, _ in
            guard let location = location else {
                return []
            }

            let localizedString = isAhead ? GDLocalizedString("first_launch.beacon.callout.ahead") : GDLocalizedString("first_launch.beacon.callout.behind")
            return [TTSSound(localizedString, at: destinationPOI.closestLocation(from: location))]
        })]

        return CalloutGroup(callouts, action: .clear, logContext: "onboarding.beacon.orientation")
    }

    private func destinationPOIForCurrentDestination(destinationPOI: POI?) async -> POI? {
        if let destinationPOI {
            return destinationPOI
        }

        guard let destinationManager = OnboardingRuntime.destinationManager(),
              let destinationKey = destinationManager.destinationKey else {
            return nil
        }

        if let destinationEntityKey = destinationManager.destinationEntityKey(forReferenceID: destinationKey),
           let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: destinationEntityKey) {
            return destinationPOI
        }

        return destinationManager.destinationPOI(forReferenceID: destinationKey)
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
