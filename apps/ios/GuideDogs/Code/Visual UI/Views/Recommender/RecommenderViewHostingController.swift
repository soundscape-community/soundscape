//
//  RecommenderViewHostingController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI
import CocoaLumberjackSwift

class RecommenderViewHostingController: UIHostingController<AnyView> {
    
    init() {
        let navHelper = RecommenderNavigationHelper()
        let view = RecommenderView(viewModel: RecommenderViewModel())
            .environmentObject(navHelper as ViewNavigationHelper)
        
        super.init(rootView: AnyView(view))
        
        super.view.backgroundColor = UIColor.clear
        
        navHelper.host = self
    }
    
    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        view.sizeToFit()
        preferredContentSize.height = view.bounds.height
    }
    
}
