//
//  DonationView.swift
//  Soundscape
//
//  Created by Robert Murray on 29/01/2025.
//  Copyright © 2025 Soundscape community. Licensed under the MIT license

import SwiftUI

struct DonationView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing:32.0) {
            GDLocalizedTextView("donation.title")
                .font(.largeTitle.bold())
                .foregroundColor(Color.primaryForeground)
                .accessibilityAddTraits(.isHeader)
            GDLocalizedTextView("donation.body")
                .font(.body)
                .foregroundColor(Color.primaryForeground)
            Button(action: {
                if let url = URL(string: "https://gofund.me/1441f743") {
                    UIApplication.shared.open(url)
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                GDLocalizedTextView("donation.link")
                    .onboardingButtonTextStyle()
            }
        }
        .padding(.horizontal, 18.0)
        .linearGradientBackground(.darkBlue, ignoresSafeArea: true)
    }
}

#Preview {
    DonationView()
}
