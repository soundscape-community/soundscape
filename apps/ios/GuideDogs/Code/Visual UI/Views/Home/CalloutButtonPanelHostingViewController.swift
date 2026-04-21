//
//  CalloutButtonPanelHostingViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

class CalloutButtonPanelHostingViewController: UIHostingController<CalloutButtonPanelView> {

    // MARK: Initialization

    init(logContext: String?) {
        super.init(rootView: CalloutButtonPanelView(logContext: logContext))

        view.backgroundColor = .clear
    }

    @available(*, unavailable, message: "Use init(logContext:)")
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("Use init(logContext:)")
    }

    // MARK: View Life Cycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = preferredContentSize.width
        let height = UIView.preferredContentHeightCompressedHeight(for: view)

        preferredContentSize = CGSize(width: width, height: height)
    }

}
