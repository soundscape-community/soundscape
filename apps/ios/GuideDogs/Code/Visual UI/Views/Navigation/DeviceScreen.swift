// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SceneKit
import SwiftUI
import UIKit

final class DeviceScreenModel: ObservableObject {
    @Published var illustration: UIImage?
    @Published var instructions: String?
    @Published var primaryTitle: String?
    @Published var secondaryTitle: String?
    @Published var secondaryHint: String?
    @Published var usesLightPrimaryStyle = true
    @Published var showsGenericHeadset = false
    @Published var showsScene = false
    @Published var focusRequest = 0

    var primaryAction: () -> Void = {}
    var secondaryAction: () -> Void = {}
}

struct DeviceScreen: View {
    @ObservedObject var model: DeviceScreenModel
    let scene: SCNView
    @AccessibilityFocusState private var primaryFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 12) {
                    GeometryReader { geometry in
                        ZStack {
                            if let illustration = model.illustration {
                                Image(uiImage: illustration)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: 350)
                                    .clipped()
                            }
                            if model.showsGenericHeadset || model.showsScene {
                                Circle().fill(Color("Foreground 1"))
                                    .frame(width: 148, height: 148)
                                    .overlay {
                                        if model.showsGenericHeadset {
                                            Image("GenericHeadset").resizable().scaledToFit()
                                        } else {
                                            EmbeddedView(content: scene)
                                        }
                                    }
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 350)
                    .accessibilityHidden(true)

                    if let instructions = model.instructions {
                        Text(verbatim: instructions)
                            .foregroundStyle(Color("Foreground 1"))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(12)
            }

            VStack(spacing: 8) {
                if let title = model.secondaryTitle {
                    button(title, light: true, action: model.secondaryAction)
                        .accessibilityHint(Text(verbatim: model.secondaryHint ?? ""))
                }
                if let title = model.primaryTitle, !title.isEmpty {
                    button(title, light: model.usesLightPrimaryStyle, action: model.primaryAction)
                        .accessibilityFocused($primaryFocused)
                }
            }
            .padding([.horizontal, .bottom], 12)
        }
        .onChange(of: model.focusRequest) { _ in primaryFocused = true }
    }

    private func button(_ title: String, light: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, 12)
                .foregroundStyle(Color(light ? "Background 2" : "Foreground 1"))
                .background(Color(light ? "Foreground 1" : "Background 3"), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}
