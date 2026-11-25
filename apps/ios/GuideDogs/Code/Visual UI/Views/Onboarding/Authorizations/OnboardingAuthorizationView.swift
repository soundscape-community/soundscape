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
    @EnvironmentObject private var viewModel: OnboardingViewModel

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
            guard viewModel.coordinator.path.last == .authorizations else { return }
            viewModel.open(viewModel.coordinator.routeAfterAuthorizations(allGranted: motion.isAuthorized && location.isAuthorized))
        }
    }

    
}

struct OnboardingAuthorizationView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingAuthorizationView().environmentObject(OnboardingViewModel())
    }
    
}
