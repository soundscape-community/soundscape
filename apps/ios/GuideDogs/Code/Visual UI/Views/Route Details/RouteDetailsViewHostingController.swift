//
//  RouteDetailsViewHostingController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

class RouteDetailsViewHostingController: UIHostingController<AnyView> {
    init(routeGuidance: RouteGuidance) {
        let navHelper = ViewNavigationHelper()
        let view = RouteDetailsView(routeGuidance.content, deleteAction: nil)
            .environmentObject(UserLocationStore())
            .environmentObject(navHelper)
        
        super.init(rootView: AnyView(view))
        
        navHelper.host = self
    }

    @available(*, unavailable, message: "Use init(routeGuidance:)")
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init(routeGuidance:)")
    }

    static func makeForActiveRoute() -> RouteDetailsViewHostingController? {
        guard let routeGuidance = AppContext.shared.eventProcessor.activeBehavior as? RouteGuidance else {
            return nil
        }

        return RouteDetailsViewHostingController(routeGuidance: routeGuidance)
    }
}
