//
//  OnboardingTermsView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct OnboardingTermsView: View {
    
    // MARK: Properties
    
    @State private var isNavigationLinkActive = false
    
    @ViewBuilder
    private var destination: some View {
        OnboardingPromptView()
    }
    
    // MARK: `body`
    
    var body: some View {
        VStack(spacing: 0.0) {
            FirstLaunchTermsView {
                
                isNavigationLinkActive = true
            }
            .padding(.vertical, 48.0)
            
            NavigationLink(
                destination: destination,
                isActive: $isNavigationLinkActive,
                label: {
                    EmptyView()
                })
                .accessibilityHidden(true)
        }
        .linearGradientBackground(.darkBlue, ignoresSafeArea: true)
        .navigationBarHidden(true)
        .accessibilityIgnoresInvertColors(true)

    }
    
}

struct FirstLaunchTermsView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingTermsView()
    }
    
}
