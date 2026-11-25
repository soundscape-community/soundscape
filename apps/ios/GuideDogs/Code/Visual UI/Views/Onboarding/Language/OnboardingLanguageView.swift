//
//  OnboardingLanguageView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct OnboardingLanguageView: View {
    
    // MARK: Properties
    
    @State private var selectedLocale: Locale = LocalizationContext.currentAppLocale
    
    
    // MARK: `body`
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 12.0) {
                GDLocalizedTextView("first_launch.soundscape_language")
                    .onboardingHeaderTextStyle()
                
                GDLocalizedTextView("first_launch.beacon.message.3")
                    .onboardingTextStyle(font: .callout)
            }
            
            LanguagePickerView(selectedLocale: $selectedLocale)
            
            OnboardingNavigationLink(route: .headphones)
        }

    }
    
}

struct OnboardingLanguageView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingLanguageView()
    }
    
}
