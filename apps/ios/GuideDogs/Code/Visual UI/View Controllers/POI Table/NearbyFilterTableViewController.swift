//
//  NearbyFilterTableViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

// Presents the shared filter list inside UIKit flows such as the waypoint editor.
class NearbyFilterViewController: UIViewController, POITableViewController {
    weak var delegate: POITableViewDelegate?
    var onDismissPreviewHandler: (() -> Void)?
    private let context = NearbyDataContext()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = GDLocalizedString("search.nearby.screen_title")
        navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        if delegate?.doneNavigationItem == true {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: GDLocalizedString("general.alert.done"),
                primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
            )
        }

        let host = UIHostingController(rootView: NearbyFiltersContent(context: context) { [weak self] filter in
            guard let self else { return }
            let nearby = NearbyResultsViewController()
            nearby.delegate = self.delegate
            nearby.onDismissPreviewHandler = self.onDismissPreviewHandler
            nearby.context = self.context
            nearby.currentFilter = filter
            self.navigationController?.pushViewController(nearby, animated: true)
        })
        add(host) { content in
            [
                content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        }
    }
}
