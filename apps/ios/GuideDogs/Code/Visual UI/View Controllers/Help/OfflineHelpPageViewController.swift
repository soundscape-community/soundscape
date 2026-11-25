//
//  OfflineHelpPageViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

class OfflineHelpPageViewController: HelpHostingController {
    init() {
        let page = HelpContentView(sections: [
            .init(title: GDLocalizedString("help.offline.page_title"),
                  paragraphs: [GDLocalizedString("help.offline.description")]),
            .init(title: GDLocalizedString("help.offline.limitations_heading"),
                  paragraphs: [GDLocalizedString("help.offline.limitations_description")]),
            .init(title: GDLocalizedString("help.offline.troubleshooting_heading"),
                  paragraphs: [GDLocalizedString("help.offline.troubleshooting_description")])
        ])
        super.init(title: GDLocalizedString("help.offline.section_title"), content: AnyView(page))
    }

    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }
}
