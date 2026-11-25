//
//  NewFeaturesViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

final class NewFeaturesModel: ObservableObject {
    let features: [FeatureInfo]
    @Published var index = 0
    var onDone: () -> Void = {}

    init(features: [FeatureInfo]) {
        self.features = features
    }
}

struct NewFeaturesView: View {
    @ObservedObject var model: NewFeaturesModel
    @AccessibilityFocusState private var headerIsFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            GDLocalizedTextView("settings.new_feature.recent_updates")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headerIsFocused)

            if model.features.isEmpty {
                closeButton(title: GDLocalizedString("general.alert.done"))
            } else {
                TabView(selection: $model.index) {
                    ForEach(model.features.indices, id: \.self) { index in
                        featurePage(model.features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                let feature = model.features[model.index]
                let isLast = model.index == model.features.count - 1
                GDLocalizedTextView("settings.new_feature.num_of_num", String(model.index + 1), String(model.features.count))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: move(by: 1)
                        case .decrement: move(by: -1)
                        @unknown default: break
                        }
                    }

                closeButton(title: feature.buttonLabel ?? GDLocalizedString(isLast ? "general.alert.done" : "general.alert.next"))
                    .accessibilityHint(Text(verbatim: feature.buttonAccessibilityHint ?? GDLocalizedString(
                        isLast ? "settings.new_feature.accept_button.acc_label" : "settings.new_feature.accept_button.acc_hint"
                    )))
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(Color("Background Base"), in: RoundedRectangle(cornerRadius: 16))
        .padding(16)
        .background { Color.black.opacity(0.5).ignoresSafeArea() }
        .onAppear { headerIsFocused = true }
    }

    private func featurePage(_ feature: FeatureInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = feature.localizedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 283)
                        .accessibilityHidden(true)
                }

                Text(verbatim: feature.localizedTitle)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                Text(description(for: feature))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    private func description(for feature: FeatureInfo) -> AttributedString {
        let text = feature.localizedDescription
        let attributed = NSMutableAttributedString(string: text)
        if let start = feature.hyperlinkStart, let length = feature.hyperlinkLength,
           let url = feature.hyperlinkURL, start >= 0, length > 0,
           start <= attributed.length, length <= attributed.length - start {
            attributed.addAttribute(.link, value: url, range: NSRange(location: start, length: length))
        }
        return AttributedString(attributed)
    }

    private func closeButton(title: String) -> some View {
        Button {
            if model.index + 1 < model.features.count {
                move(by: 1)
            } else {
                model.onDone()
            }
        } label: {
            Text(verbatim: title)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private func move(by offset: Int) {
        let next = model.index + offset
        guard model.features.indices.contains(next) else { return }
        withAnimation { model.index = next }
    }
}

struct NewFeaturesPresentation: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: NewFeaturesModel
    let service: NewFeatures

    init(service: NewFeatures) {
        self.service = service
        let features = service.features.values.joined().sorted {
            $0.version < $1.version || ($0.version == $1.version && $0.order < $1.order)
        }
        _model = StateObject(wrappedValue: NewFeaturesModel(features: features))
    }

    var body: some View {
        NewFeaturesView(model: model)
            .interactiveDismissDisabled()
            .onAppear {
                model.onDone = {
                    service.newFeaturesDidShow()
                    dismiss()
                }
            }
    }
}
