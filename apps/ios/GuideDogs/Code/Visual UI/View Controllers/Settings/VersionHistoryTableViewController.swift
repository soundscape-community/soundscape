//
//  VersionHistoryTableViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct VersionHistoryScreen: View {
    private let features = NewFeatures.allFeaturesHistory() ?? [:]
    @State private var selected: Selection?

    var body: some View {
        VStack(spacing: 0) {
            NavigationBanner()
            List {
                ForEach(features.keys.sorted(by: >), id: \.string) { version in
                    Section(GDLocalizedString("settings.version.history.version", version.string)) {
                        ForEach(features[version] ?? [], id: \.order) { feature in
                            Button {
                                selected = Selection(feature: feature)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feature.localizedTitle).foregroundStyle(.primary)
                                    Text(feature.localizedDescription).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.grouped)
        }
        .navigationTitle(GDLocalizedString("settings.about.title.whats_new"))
        .toolbar(.visible, for: .navigationBar)
        .fullScreenCover(item: $selected) { selection in
            FeatureHistoryPresentation(feature: selection.feature)
        }
    }

    private struct Selection: Identifiable {
        let feature: FeatureInfo
        var id: Int { feature.order }
    }
}

private struct FeatureHistoryPresentation: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: NewFeaturesModel

    init(feature: FeatureInfo) {
        _model = StateObject(wrappedValue: NewFeaturesModel(features: [feature]))
    }

    var body: some View {
        NewFeaturesView(model: model)
            .onAppear { model.onDone = { dismiss() } }
    }
}
