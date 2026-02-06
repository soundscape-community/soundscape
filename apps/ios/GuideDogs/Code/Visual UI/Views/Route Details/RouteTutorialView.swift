//
//  RouteTutorialView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI
import CoreLocation

struct RouteTutorialView: View {
    
    @EnvironmentObject var navHelper: ViewNavigationHelper
    
    let detail: RouteDetail
    
    @Binding var isShown: Bool

    private func makeRouteGuidance() -> RouteGuidance? {
        guard let spatialData = VisualRuntimeProviderRegistry.providers.visualSpatialDataContext(),
              let motion = VisualRuntimeProviderRegistry.providers.visualMotionActivityContext() else {
            return nil
        }

        return RouteGuidance(detail, spatialData: spatialData, motion: motion)
    }
    
    private func startGuidance(_ guidance: RouteGuidance) {
        if VisualRuntimeProviderRegistry.providers.visualIsCustomBehaviorActive() {
            VisualRuntimeProviderRegistry.providers.visualDeactivateCustomBehavior()
        }
        
        // Try to make VoiceOver focus on the beacon panel after we pop to the home view controller
        if let home = navHelper.host?.navigationController?.viewControllers.first as? HomeViewController {
            home.shouldFocusOnBeacon = true
        }
        
        VisualRuntimeProviderRegistry.providers.visualActivateCustomBehavior(guidance)
        navHelper.popToRootViewController(animated: true)
    }
    
    var body: some View {
        ZStack {
            Color
                .primaryBackground
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                ScrollView {
                    VStack {
                        GDLocalizedTextView("routes.tutorial.title")
                            .foregroundColor(.primaryForeground)
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits([.isHeader])
                            .padding()
                        
                        Image("destination_graphic03")
                            .resizable()
                            .scaledToFit()
                            .accessibilityHidden(true)
                        
                        GDLocalizedTextView("routes.tutorial.details")
                            .locationNameTextFormat()
                            .multilineTextAlignment(.center)
                            .padding([.leading, .trailing], 20)
                            .padding([.top, .bottom])
                    }
                }
                
                HStack {
                    Spacer()
                    
                    Button {
                        // Start the route and pop to the home screen
                        guard let guidance = makeRouteGuidance() else {
                            return
                        }
                        startGuidance(guidance)
                        FirstUseExperience.setDidComplete(for: .routeTutorial)
                    } label: {
                        GDLocalizedTextView("general.alert.dismiss")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 48.0)
                            .padding(.vertical, 10.0)
                            .background(Color.primaryForeground)
                            .foregroundColor(Color.primaryBackground)
                            .cornerRadius(5.0)
                    }

                    Spacer()
                }
                .foregroundColor(.secondaryForeground)
                .padding([.leading, .trailing], 24)
                .padding([.top, .bottom])
            }
        }
    }
}

struct RouteTutorialView_Previews: PreviewProvider {
    static var previews: some View {
        RouteTutorialView(detail: RouteDetail(source: .database(id: Route.sample.id)), isShown: .constant(true))
    }
}
