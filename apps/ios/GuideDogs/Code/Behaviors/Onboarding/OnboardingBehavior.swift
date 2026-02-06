//
//  OnboardingBehavior.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

extension Notification.Name {
    static let onboardingDidComplete = Notification.Name("GDAOnboardingDidComplete")
}

@MainActor
enum OnboardingRuntime {
    static func destinationManager() -> DestinationManagerProtocol? {
        BehaviorRuntimeProviderRegistry.providers.onboardingDestinationManager()
    }

    static func currentUserLocation() -> CLLocation? {
        BehaviorRuntimeProviderRegistry.providers.onboardingCurrentUserLocation()
    }

    static func currentPresentationHeading() -> CLLocationDirection? {
        BehaviorRuntimeProviderRegistry.providers.onboardingCurrentPresentationHeading()
    }

    static func isGeolocationAuthorized() -> Bool {
        BehaviorRuntimeProviderRegistry.providers.onboardingIsGeolocationAuthorized()
    }

    static func isMotionActivityAuthorized() -> Bool {
        BehaviorRuntimeProviderRegistry.providers.onboardingIsMotionActivityAuthorized()
    }
}

@MainActor
class OnboardingBehavior: BehaviorBase {
    
    // MARK: Enums
    
    enum Context {
        case firstUse
        case help
    }
    
    // MARK: Properties
    
    let context: Context
    private let beaconDemo = BeaconDemoHelper()
    private let calloutGenerator = OnboardingCalloutGenerator()
    
    // MARK: Initialization
    
    init(context: Context) {
        self.context = context
        
        super.init(blockedAutoGenerators: [AutoCalloutGenerator.self, BeaconCalloutGenerator.self, IntersectionGenerator.self],
                   blockedManualGenerators: [AutoCalloutGenerator.self, BeaconCalloutGenerator.self] )

        manualGenerators.append(calloutGenerator)
    }

    override func handleEvent(_ event: Event, blockedAuto: [AutomaticGenerator.Type] = [], blockedManual: [ManualGenerator.Type] = [], completion: @escaping ([HandledEventAction]?) -> Void) {
        if handleLocalEvent(event) {
            completion(nil)
            return
        }

        super.handleEvent(event, blockedAuto: blockedAuto, blockedManual: blockedManual, completion: completion)
    }
    
    override func activate(with parent: Behavior?) {
        super.activate(with: parent)
        
        if let manager = OnboardingRuntime.destinationManager(), manager.isAudioEnabled {
            // If there is an existing beacon, turn off beacon audio
            manager.toggleDestinationAudio(true)
        }
    }
    
    override func willDeactivate() {
        super.willDeactivate()
        
        guard context == .firstUse else {
            // If onboarding has already been completed,
            // no further actions are requied
            return
        }
        
        FirstUseExperience.setDidComplete(for: .oobe)
        
        // Track first app use
        SettingsContext.shared.appUseCount += 1
        
        // Play spatial audio if required services are authorized
        if OnboardingRuntime.isGeolocationAuthorized() && OnboardingRuntime.isMotionActivityAuthorized() {
            // Play app launch sound
            delegate?.process(GlyphEvent(.appLaunch))
            
            // Start a `My Location` callout
            delegate?.process(ExplorationModeToggled(.locate, logContext: "first_launch"))
        }
        
        // Post notification
        NotificationCenter.default.post(name: .onboardingDidComplete, object: self)
    }
    
}

struct OnboardingExampleCalloutEvent: UserInitiatedEvent {
    var completion: ((Bool) -> Void)?
}

struct StartSelectedBeaconAudioEvent: UserInitiatedEvent { }
struct StopSelectedBeaconAudioEvent: UserInitiatedEvent { }

struct SelectedBeaconCalloutEvent: UserInitiatedEvent {
    var completion: ((Bool) -> Void)?
}

struct SelectedBeaconOrientationCalloutEvent: UserInitiatedEvent {
    var isAhead: Bool
}

// MARK: - Private helpers

private extension OnboardingBehavior {
    func handleLocalEvent(_ event: Event) -> Bool {
        guard let userEvent = event as? UserInitiatedEvent else {
            return false
        }

        switch userEvent {
        case is StartSelectedBeaconAudioEvent:
            _ = startSelectedBeaconAudio()
            return true

        case is StopSelectedBeaconAudioEvent:
            beaconDemo.restoreState(logContext: "onboarding")
            return true

        default:
            return false
        }
    }

    func startSelectedBeaconAudio() -> Bool {
        guard let userLocation = OnboardingRuntime.currentUserLocation() else {
            return false
        }

        guard let heading = OnboardingRuntime.currentPresentationHeading() else {
            return false
        }

        guard let beacon = BeaconOption(id: SettingsContext.shared.selectedBeacon) else {
            return false
        }

        beaconDemo.prepare()

        let location = CLLocation(userLocation.coordinate.destination(distance: 100.0,
                                                                      bearing: heading.add(degrees: beacon.style.defaultBearing)))
        beaconDemo.play(shouldTimeOut: false, newBeaconLocation: location, logContext: "onboarding")
        return true
    }
}

private extension BeaconOption.Style {
    var defaultBearing: Double {
        switch self {
        case .standard: return 45.0
        case .haptic: return 0.0
        }
    }
}
