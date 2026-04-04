//
//  LanguageSettingsHostViewController.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

class LanguageSettingsHostViewController: UIHostingController<LanguageSettingsView> {
    init() {
        super.init(rootView: LanguageSettingsView())
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init()")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Colors.Background.quaternary

        let segmentedControlAppearance = UISegmentedControl.appearance(
            whenContainedInInstancesOf: [LanguageSettingsHostViewController.self]
        )
        segmentedControlAppearance.selectedSegmentTintColor = Colors.Foreground.primary
        segmentedControlAppearance.backgroundColor = Colors.Background.tertiary
        segmentedControlAppearance.setTitleTextAttributes(
            [.foregroundColor: Colors.Background.secondary!],
            for: .selected
        )
        segmentedControlAppearance.setTitleTextAttributes(
            [.foregroundColor: Colors.Foreground.primary!],
            for: .normal
        )
    }
}
