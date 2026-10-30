//
//  OnboardingWelcomeView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI

struct OnboardingWelcomeView: View {
    
    // MARK: Properties
    
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    let context: OnboardingBehavior.Context
    
    @ViewBuilder
    private var destination: some View {
        if LocalizationContext.deviceLocale.identifierHyphened == LocalizationContext.currentAppLocale.identifierHyphened {
            OnboardingHeadphoneView()
        } else {
            OnboardingLanguageView()
        }
    }
    
    // MARK: `body`
    
    var body: some View {
        NavigationView {
            OnboardingContainer(coverImage: Image("permissions-intro"), accessibilityLabel: GDLocalizationUnnecessary("Soundscape")) {
                Spacer()
                
                VStack(spacing: 12.0) {
                    GDLocalizedTextView("first_launch.welcome.title")
                        .onboardingHeaderTextStyle()
                        .accessibilityLabel(GDLocalizedTextView("first_launch.welcome.title.accessibility_label"))
                    
                    GDLocalizedTextView("first_launch.welcome.description")
                        .onboardingTextStyle()
                }
                
                Spacer()
                
                OnboardingNavigationLink(text: GDLocalizedString("first_launch.welcome.button"), destination: destination)
            }
        }
        .accentColor(.primaryForeground)
        .onAppear {
            viewModel.activateOnboarding(context: context)
        }
        .onDisappear {
            viewModel.onboardingDidDisappear()
        }
    }
    
}

struct FirstLaunchWelcomeView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingWelcomeView(context: .firstUse)
            .environmentObject(OnboardingViewModel())
    }
    
}
