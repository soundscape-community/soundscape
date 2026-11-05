//
//  ShareRouteActivityViewRepresentable.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

struct ShareRouteActivityViewRepresentable: ViewControllerRepresentable {
    
    // MARK: Properties
    
    let route: RouteDetail
    
    // MARK: `ViewControllerRepresentable`
    
    func makeViewController() -> UIViewController? {
        
        return SoundscapeDocumentAlert.shareRoute(route)
    }
    
}
