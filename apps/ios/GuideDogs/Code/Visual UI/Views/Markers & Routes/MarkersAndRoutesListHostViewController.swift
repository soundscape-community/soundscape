//
//  MarkersAndRoutesListHostViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

class MarkersAndRoutesListHostViewController: UIHostingController<AnyView> {
    init() {
        let navHelper = MarkersAndRoutesListNavigationHelper()
        let root = MarkersAndRoutesList()
            .environmentObject(navHelper)
            .environmentObject(UserLocationStore())
            .environment(\.realmConfiguration, RealmHelper.databaseConfig)
        
        super.init(rootView: AnyView(root))
        
        navHelper.host = self
    }
    
    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    var onDismissPreviewHandler: (() -> Void)?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure the back button
        navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem

        // Configure the navigation bar
        let navigationBar = navigationController?.navigationBar
        navigationBar?.configureAppearance(for: .default)
        navigationBar?.standardAppearance.shadowColor = .clear
        navigationBar?.scrollEdgeAppearance?.shadowColor = .clear
        navigationBar?.compactAppearance?.shadowColor = .clear
        navigationBar?.compactScrollEdgeAppearance?.shadowColor = .clear
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        guard parent == nil else {
            return
        }
        
        // If the user has returned to the Home screen from Saved Markers, remove the
        // isNew flag from all marked points.
        do {
            try SpatialDataCache.clearNewReferenceEntities()
            try SpatialDataCache.clearNewRoutes()
        } catch {
            GDLogAppError("Unable to clear isNew flag for reference entities!")
        }
    }
}
