//
//  OnboardingNavigationLink.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct OnboardingNavigationLink: View {
    
    // MARK: Properties
    
    private let text: String
    private let route: OnboardingRoute
    
    // MARK: Initialization
    
    init(text: String = GDLocalizedString("ui.continue"), route: OnboardingRoute) {
        self.text = text
        self.route = route
    }
    
    // MARK: `body`
    
    var body: some View {
        NavigationLink(value: route) {
            Text(text)
                .onboardingButtonTextStyle()
        }
        .padding(.horizontal, 24.0)
    }
    
}

struct OnboardingNavigationLink_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingContainer {
            // Try default text
            OnboardingNavigationLink(route: .headphones)
            
            // Try custom text
            OnboardingNavigationLink(text: "Press Me!", route: .headphones)
        }
    }
    
}
