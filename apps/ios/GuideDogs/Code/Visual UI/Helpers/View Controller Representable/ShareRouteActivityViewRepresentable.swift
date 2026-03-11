//
//  ShareRouteActivityViewRepresentable.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import UIKit

@MainActor
struct ShareRouteActivityViewRepresentable: ViewControllerRepresentable {
    enum RouteSource {
        case detail(RouteDetail)
        case prebuilt(UIViewController)
    }
    
    // MARK: Properties
    
    let routeSource: RouteSource

    init(route: RouteDetail) {
        self.routeSource = .detail(route)
    }

    init(viewController: UIViewController) {
        self.routeSource = .prebuilt(viewController)
    }
    
    // MARK: `ViewControllerRepresentable`
    
    func makeViewController() -> UIViewController? {
        GDATelemetry.track("share.route")

        switch routeSource {
        case .detail(let routeDetail):
            return SoundscapeDocumentAlert.shareRoute(routeDetail)
        case .prebuilt(let viewController):
            return viewController
        }
    }
    
}
