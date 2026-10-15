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
    var isOnboardingActive = false
    var didComplete = false

    func deactivateOnboarding() {
        guard isOnboardingActive else { return }
        isOnboardingActive = false
        AppContext.shared.eventProcessor.deactivateCustom()
    }
    
    // MARK: Initialization
    
    init(dismiss: @escaping () -> Void = { }) {
        self.dismiss = dismiss
    }
    
}
