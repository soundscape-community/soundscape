//
//  VolumeControlsHostViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

class VolumeControlsHostViewController: UIHostingController<AnyView> {
    init() {
        super.init(rootView: AnyView(VolumeControls()))
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init()")
    }
}
