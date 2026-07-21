//
//  AuthoredActivitiesListHostingController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

class AuthoredActivitiesListHostingController: UIHostingController<AnyView> {
    init() {
        let navHelper = ViewNavigationHelper()
        let storage = AuthoredActivityStorage(AuthoredActivityLoader.shared)
        let view = AuthoredActivitiesList().environmentObject(storage).environmentObject(navHelper)
        
        super.init(rootView: AnyView(view))
        
        navHelper.host = self
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init()")
    }
}
