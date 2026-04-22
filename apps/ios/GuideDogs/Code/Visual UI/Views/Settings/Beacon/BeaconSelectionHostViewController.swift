//
//  BeaconSelectionHostViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

class BeaconSelectionHostViewController: UIHostingController<AnyView> {
    init() {
        super.init(rootView: AnyView(BeaconSelectionView()))
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init()")
    }
}
