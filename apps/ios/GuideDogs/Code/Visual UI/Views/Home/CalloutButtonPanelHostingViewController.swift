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

    // MARK: Properties

    private let model: CalloutButtonPanelModel

    // MARK: Initialization

    init(logContext: String?) {
        let model = CalloutButtonPanelModel(logContext: logContext)
        self.model = model

        super.init(rootView: CalloutButtonPanelView(model: model))

        view.backgroundColor = .clear
    }

    @available(*, unavailable, message: "Use init(logContext:)")
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("Use init(logContext:)")
    }

    // MARK: Callout Actions

    func perform(_ action: CalloutButtonPanelAction, sender: AnyObject? = nil) {
        model.perform(action, sender: sender)
    }

    // MARK: View Life Cycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = preferredContentSize.width
        let height = UIView.preferredContentHeightCompressedHeight(for: view)

        preferredContentSize = CGSize(width: width, height: height)
    }

}
