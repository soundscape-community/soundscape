//
//  BeaconViewHostingController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI

class BeaconViewHostingController: UIHostingController<AnyView> {
    
    init() {
        let navHelper = ViewNavigationHelper()
        
        let view = BeaconView()
            .environmentObject(BeaconDetailStore())
            .environmentObject(UserLocationStore())
            .environmentObject(navHelper)
        
        super.init(rootView: AnyView(view))
        
        navHelper.host = self
    }
    
    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let height = UIView.preferredContentHeightCompressedHeight(for: view)
        preferredContentSize.height = height
        
        self.view.invalidateIntrinsicContentSize()
    }
    
}
