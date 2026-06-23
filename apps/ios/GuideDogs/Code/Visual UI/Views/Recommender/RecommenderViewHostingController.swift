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
    
    required init?(coder aDecoder: NSCoder) {
        let navHelper = RecommenderNavigationHelper()
        let view = RecommenderView(viewModel: RecommenderViewModel())
            .environmentObject(navHelper as ViewNavigationHelper)
        
        super.init(coder: aDecoder, rootView: AnyView(view))
        
        super.view.backgroundColor = UIColor.clear
        
        navHelper.host = self
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        view.sizeToFit()
        preferredContentSize.height = view.bounds.height
    }
    
}
