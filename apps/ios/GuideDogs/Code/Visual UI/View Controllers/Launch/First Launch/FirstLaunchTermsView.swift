//
//  FirstLaunchTermsView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI

struct FirstLaunchTermsView: View {
    let onTermsAccepted: () -> Void

    @State private var accepted = false

    var body: some View {
        OnboardingContainer {
            GDLocalizedTextView("terms_of_use.title")
                .onboardingHeaderTextStyle()
                .accessibilityAddTraits(.isHeader)

            Text(agreement)
                .onboardingTextStyle()

            GDLocalizedTextView("terms_of_use.medical_safety_disclaimer")
                .onboardingTextStyle()

            GDLocalizedTextView("terms_of_use.message.prompt")
                .onboardingTextStyle()

            Button {
                accepted.toggle()
            } label: {
                Label {
                    GDLocalizedTextView("terms_of_use.accept_checkbox.acc_label")
                } icon: {
                    Image(systemName: accepted ? "checkmark.square.fill" : "square")
                }
                .frame(minHeight: 44)
            }
            .foregroundStyle(.white)
            .accessibilityValue(GDLocalizedTextView(accepted ? "terms_of_use.accept_checkbox.on.acc_value" : "terms_of_use.accept_checkbox.off.acc_value"))
            .accessibilityHint(GDLocalizedTextView(accepted ? "terms_of_use.accept_checkbox.off.acc_hint" : "terms_of_use.accept_checkbox.on.acc_hint"))

            Button(action: onTermsAccepted) {
                GDLocalizedTextView("general.alert.next")
                    .onboardingButtonTextStyle()
            }
            .disabled(!accepted)
        }
    }

    private var agreement: AttributedString {
        let linkTitle = GDLocalizedString("terms_of_use.service_agreement")
        var text = AttributedString(GDLocalizedString("terms_of_use.message", linkTitle))
        if let range = text.range(of: linkTitle) {
            text[range].link = AppContext.Links.servicesAgreementURL(for: LocalizationContext.currentAppLocale)
            text[range].underlineStyle = .single
        }
        return text
    }
}
