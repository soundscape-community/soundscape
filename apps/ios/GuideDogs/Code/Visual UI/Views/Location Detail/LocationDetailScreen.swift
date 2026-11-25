// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import CoreLocation
import SwiftUI
import UIKit

final class LocationDetailScreenModel: ObservableObject {
    @Published var detail: LocationDetail?
    @Published var userLocation: CLLocation?
    @Published var isLoading = false
    @Published var bannerHeight: CGFloat = 0

    let banner = UIView()
    let map = UIView()
    var performAction: (LocationAction, LocationDetail) -> Void = { _, _ in }
}

struct LocationDetailScreen: View {
    @ObservedObject var model: LocationDetailScreenModel

    var body: some View {
        VStack(spacing: 0) {
            EmbeddedView(content: model.banner)
                .frame(height: model.bannerHeight)
                .clipped()
                .accessibilityHidden(model.bannerHeight == 0)

            ZStack {
                ScrollView {
                    EmbeddedView(content: model.map)
                        .frame(height: 170)

                    if let detail = model.detail {
                        let labels = detail.labels
                        VStack(alignment: .leading, spacing: 12) {
                            Text(verbatim: labels.name().text)
                                .font(.headline)
                                .accessibilityLabel(Text(verbatim: labels.name().accessibilityText ?? labels.name().text))
                                .accessibilityAddTraits(.isHeader)

                            if let distance = labels.distance(from: model.userLocation) {
                                info(text: distance.text, label: distance.accessibilityText, image: "Map_iconY@22")
                            }
                            info(text: labels.address.text, label: labels.address.accessibilityText, image: "Location_iconB@22")

                            if detail.isMarker || detail.annotation != nil {
                                info(text: labels.annotation.text, label: labels.annotation.accessibilityText, image: "Annotation_iconB@22")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)

                        let actions = LocationAction.actions(for: detail)
                        VStack(spacing: 1) {
                            ForEach(actions.indices, id: \.self) { index in
                                let action = actions[index]
                                Button {
                                    model.performAction(action, detail)
                                } label: {
                                    HStack(spacing: 12) {
                                        if let image = action.image {
                                            Image(uiImage: image).accessibilityHidden(true)
                                        }
                                        Text(verbatim: action.text)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(Color("Background 2"))
                                .accessibilityHint(Text(verbatim: action.accessibilityHint ?? ""))
                                .accessibilityIdentifier(action.accessibilityIdentifier ?? "")
                                .disabled(!action.isEnabled)
                            }
                        }
                    }
                }

                if model.isLoading {
                    Color("Background Base").opacity(0.85)
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
        }
        .foregroundStyle(Color("Foreground 1"))
        .background(Color("Background Base").ignoresSafeArea())
    }

    private func info(text: String, label: String?, image: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(image).accessibilityHidden(true)
            Text(verbatim: text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: label ?? text))
    }
}
