// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI

struct TelemetryConsentView: View {
    let onChoice: () -> Void

    @State private var didChoose = false

    var body: some View {
        OnboardingContainer {
            GDLocalizedTextView("telemetry.consent.title")
                .onboardingHeaderTextStyle()
                .accessibilityAddTraits(.isHeader)

            GDLocalizedTextView("telemetry.consent.message")
                .onboardingTextStyle()

            Button {
                choose(sharingEnabled: true)
            } label: {
                GDLocalizedTextView("settings.section.share_usage_data")
                    .onboardingButtonTextStyle()
            }
            .accessibilityIdentifier("telemetry.consent.share")

            Button {
                choose(sharingEnabled: false)
            } label: {
                GDLocalizedTextView("telemetry.consent.dont_share")
                    .onboardingButtonTextStyle()
            }
            .accessibilityIdentifier("telemetry.consent.dont_share")
        }
        .disabled(didChoose)
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .accessibilityAction(.escape) { }
    }

    private func choose(sharingEnabled: Bool) {
        guard !didChoose else { return }
        didChoose = true
        GDATelemetry.setConsent(sharingEnabled: sharingEnabled)
        onChoice()
    }
}
