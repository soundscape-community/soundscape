//
//  OfflineHelpPageViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct OfflineHelpContentView: View {
    var body: some View {
        HelpContentView(sections: [
            .init(title: GDLocalizedString("help.offline.page_title"),
                  paragraphs: [GDLocalizedString("help.offline.description")]),
            .init(title: GDLocalizedString("help.offline.limitations_heading"),
                  paragraphs: [GDLocalizedString("help.offline.limitations_description")]),
            .init(title: GDLocalizedString("help.offline.troubleshooting_heading"),
                  paragraphs: [GDLocalizedString("help.offline.troubleshooting_description")])
        ])
    }
}

// Banner links inside a legacy navigation controller still push onto that controller.
final class OfflineHelpPageViewController: HelpHostingController {
    init() {
        super.init(title: GDLocalizedString("help.offline.section_title"), content: AnyView(OfflineHelpContentView()))
    }

    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }
}
