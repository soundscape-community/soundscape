//
//  OnboardingAuthorizationView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct OnboardingAuthorizationView: View {
    
    // MARK: Properties
    
    @ObservedObject private var location: AuthorizationViewModel
    @ObservedObject private var motion: AuthorizationViewModel
    @State private var isNavigationLinkActive = false
    
    @ViewBuilder
    private var destination: some View {
        if motion.isAuthorized, location.isAuthorized {
            // All authorizations were provided
            // Navigate to the beacon selection view
            OnboardingBeaconView()
        } else {
            // One or more authorizations were not provided
            // Authorizations are required to listen to and select an
            // audio beacon. Skip the beacon selection view.
            if FirstUseExperience.didComplete(.oobe) {
                // If onboarding has already been completed,
                // skip `OnboardingTermsView`
                OnboardingPromptView()
            } else {
                OnboardingTermsView()
            }
        }
    }
    
    // MARK: Initialization
    
    init() {
        self.location = AuthorizationViewModel(for: .location)
        self.motion = AuthorizationViewModel(for: .motion)
    }
    
    // MARK: `body`
    
    var body: some View {
        OnboardingContainer {
            Spacer()
            
            GDLocalizedTextView("first_launch.permissions.title")
                .onboardingHeaderTextStyle()
            
            VStack(spacing: 32.0) {
                GDLocalizedTextView("first_launch.permissions.message")
                    .onboardingTextStyle()
                
                VStack(spacing: 24.0) {
                    AuthorizationItemView(service: location.service, status: location.authorizationStatus)
                    
                    AuthorizationItemView(service: motion.service, status: motion.authorizationStatus)
                }
                .padding(18.0)
                .foregroundColor(.primaryForeground)
                .background(Color.black.opacity(0.2))
                .cornerRadius(5.0)
                .accessibilityElement(children: .combine)
            }

            Spacer()
            
            Button {
                tryRequestAuthorization()
            } label: {
                GDLocalizedTextView("ui.continue")
                    .onboardingButtonTextStyle()
            }
            .padding(.horizontal, 24.0)
            
            NavigationLink(
                destination: destination,
                isActive: $isNavigationLinkActive,
                label: {
                    EmptyView()
                })
                .accessibilityHidden(true)
        }
        .onChange(of: location.authorizationStatus, perform: { _ in
            tryRequestAuthorization()
        })
        .onChange(of: motion.authorizationStatus, perform: { _ in
            tryRequestAuthorization()
        })
    }
    
    // MARK: -
    
    private func tryRequestAuthorization() {
        if !location.didRequestAuthorization {
            // First, request location authorization
            location.requestAuthorization()
        } else if !motion.didRequestAuthorization {
            // Second, request motion authorization
            motion.requestAuthorization()
        } else {
            // All authorizations have been requested
            isNavigationLinkActive = true
        }
    }

    
}

struct OnboardingAuthorizationView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingAuthorizationView()
    }
    
}
