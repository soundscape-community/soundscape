//
//  AnyViewControllerRepresentable.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

struct AnyViewControllerRepresentable: ViewControllerRepresentable {
    
    enum Destination {
        case offlineHelp
        case routeGuidance
        case manageDevices
    }
    
    // MARK: Properties
    
    let destination: Destination
    
    // MARK: `ViewControllerRepresentable`
    
    func makeViewController() -> UIViewController? {
        switch destination {
        case .offlineHelp:
            return OfflineHelpPageViewController()
        case .routeGuidance:
            return RouteDetailsViewHostingController.makeForActiveRoute()
        case .manageDevices:
            return DevicesViewController()
        }
    }
    
}

extension AnyViewControllerRepresentable {
    
    // MARK: Static Initializers
    
    static let offlineHelp = AnyViewControllerRepresentable(destination: .offlineHelp)
    static let routeGuidance = AnyViewControllerRepresentable(destination: .routeGuidance)
    static let manageDevices = AnyViewControllerRepresentable(destination: .manageDevices)
    
}
