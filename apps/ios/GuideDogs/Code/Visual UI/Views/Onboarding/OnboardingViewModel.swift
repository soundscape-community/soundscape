//
//  OnboardingViewModel.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI

class OnboardingViewModel: ObservableObject {
    
    // MARK: Properties
    
    var dismiss: () -> Void
    @Published var isPresentingTelemetryConsent = false
    private var isOnboardingActive = false
    private var didComplete = false

    func activateOnboarding(context: OnboardingBehavior.Context) {
        guard !isOnboardingActive, !didComplete else { return }
        isOnboardingActive = true
        GDATelemetry.trackScreenView("onboarding.welcome")
        // Completed onboarding means this flow was opened from app settings.
        GDATelemetry.track("onboarding.started", with: ["first_launch": "\(!FirstUseExperience.didComplete(.oobe))"])
        AppContext.shared.eventProcessor.activateCustom(behavior: OnboardingBehavior(context: context))
    }

    func onboardingDidDisappear() {
        // Presenting consent temporarily hides onboarding without ending it.
        guard !isPresentingTelemetryConsent else { return }
        deactivateOnboarding()
    }

    func requestCompletion() {
        if SettingsContext.shared.telemetryConsentChoiceMade {
            completeOnboarding()
        } else {
            isPresentingTelemetryConsent = true
        }
    }

    func completeOnboarding() {
        guard SettingsContext.shared.telemetryConsentChoiceMade, !didComplete else { return }
        didComplete = true
        GDATelemetry.track("onboarding.completed", with: ["first_launch": "\(!FirstUseExperience.didComplete(.oobe))"])
        deactivateOnboarding()
        dismiss()
    }

    private func deactivateOnboarding() {
        guard isOnboardingActive else { return }
        isOnboardingActive = false
        AppContext.shared.eventProcessor.deactivateCustom()
    }
    
    // MARK: Initialization
    
    init(dismiss: @escaping () -> Void = { }) {
        self.dismiss = dismiss
    }
    
}
