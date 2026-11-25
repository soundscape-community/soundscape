//
//  WaypointAddButton.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct WaypointAddButton: View {
    
    // MARK: Properties
    
    @EnvironmentObject var navHelper: ViewNavigationHelper
    
    @CustomScaledMetric(maxValue: 26.0, relativeTo: .body) var fontSize: CGFloat = Font.TextStyle.body.pointSize
    
    @Binding var name: String
    @Binding var identifiableWaypoints: [IdentifiableLocationDetail]
    
    // MARK: `body`
    
    var body: some View {
        VStack {
            Button(action: {
                // Ensure the keyboard is hidden when navigating to the add waypoints
                // view
                hideKeyboard()
                
                let viewController = SearchWaypointViewController()
                let navigationController = NavigationController(rootViewController: viewController)

                viewController.routeName = name
                viewController.waypoints = $identifiableWaypoints
                
                // Configure modal presentation
                navigationController.accessibilityViewIsModal = true
                
                navHelper.present(navigationController, animated: true, completion: nil)
            }, label: {
                GDLocalizedTextView("route_detail.edit.waypoints_button")
                    .font(.system(size: fontSize))
                    // Set `buttonStyle` when used in a list
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(Color.quaternaryBackground)
                    .roundedBackground(Color.primaryForeground)
                    .padding(.horizontal, 48.0)
                    .padding(.vertical, 12.0)
            })
        }
        // Set `plainListRowBackground` when used in a list
        .plainListRowBackground(Color.tertiaryBackground)
        .background(Color.tertiaryBackground)
    }
    
}

struct WaypointAddButton_Previews: PreviewProvider {
    
    static private var route = RouteDetailsView_Previews.testOMRoute
    
    static var previews: some View {
        WaypointAddButton(name: .constant(route.displayName), identifiableWaypoints: .constant(route.waypoints.asIdenfifiable))
            .environmentObject(MarkersAndRoutesListNavigationHelper())
    }
    
}
