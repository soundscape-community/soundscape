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

    // MARK: Embedding

    static func embed(
        in parentViewController: UIViewController,
        containerView: UIView,
        logContext: String?
    ) -> CalloutButtonPanelHostingViewController {
        let viewController = CalloutButtonPanelHostingViewController(logContext: logContext)

        parentViewController.addChild(viewController)
        containerView.addSubview(viewController.view)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            viewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            viewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        viewController.didMove(toParent: parentViewController)

        return viewController
    }

    static func updateTraitOverride(
        for child: CalloutButtonPanelHostingViewController?,
        in parentViewController: UIViewController
    ) {
        guard let child else {
            return
        }

        // When the preferredContentSizeCategory is an accessibility size, cap the
        // panel to keep labels readable in the limited available space.
        if parentViewController.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            parentViewController.setOverrideTraitCollection(
                UITraitCollection(preferredContentSizeCategory: .accessibilityMedium),
                forChild: child
            )
        } else {
            parentViewController.setOverrideTraitCollection(nil, forChild: child)
        }
    }

    // MARK: View Life Cycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = preferredContentSize.width
        let height = UIView.preferredContentHeightCompressedHeight(for: view)

        preferredContentSize = CGSize(width: width, height: height)
    }

}
