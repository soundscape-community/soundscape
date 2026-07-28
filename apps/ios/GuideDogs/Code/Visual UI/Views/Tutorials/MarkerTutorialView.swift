//
//  MarkerTutorialView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

enum MarkerTutorialAction: Equatable {
    case addMarker
    case nearbyMarkers
}

final class MarkerTutorialViewState: ObservableObject {
    @Published private(set) var title: String?
    @Published private(set) var image: UIImage?
    @Published private(set) var text: String?
    @Published private(set) var actionTitle: String?
    @Published private(set) var action: MarkerTutorialAction?
    @Published private(set) var isActionVisible = false
    @Published private(set) var exitTitle: String
    @Published private(set) var hidesContentFromAccessibility = false
    @Published private(set) var actionFocusRequest = 0

    init(exitTitle: String) {
        self.exitTitle = exitTitle
    }

    func clear() {
        title = nil
        image = nil
        text = nil
        actionTitle = nil
        action = nil
        isActionVisible = false
        hidesContentFromAccessibility = false
    }

    func show(title: String,
              image: UIImage,
              text: String?,
              actionTitle: String?,
              action: MarkerTutorialAction?,
              hidesContentFromAccessibility: Bool) {
        self.title = title
        self.image = image
        self.text = text
        self.actionTitle = actionTitle
        self.action = action
        self.hidesContentFromAccessibility = hidesContentFromAccessibility
        isActionVisible = false
    }

    func updateText(_ text: String?) {
        self.text = text
    }

    func revealAction(requestAccessibilityFocus: Bool = true) {
        guard actionTitle != nil, action != nil else {
            isActionVisible = false
            return
        }

        isActionVisible = true
        if requestAccessibilityFocus {
            actionFocusRequest += 1
        }
    }
}

struct MarkerTutorialView: View {
    @ObservedObject var state: MarkerTutorialViewState

    let onAction: (MarkerTutorialAction) -> Void
    let onExit: () -> Void

    @AccessibilityFocusState private var isActionFocused: Bool

    private let backgroundColor = Color(red: 36.0 / 255.0,
                                        green: 58.0 / 255.0,
                                        blue: 102.0 / 255.0)

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 20) {
                        if let title = state.title {
                            Text(title)
                                .font(.title)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityHidden(state.hidesContentFromAccessibility)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                        }

                        if let image = state.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(125.0 / 53.0, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .accessibilityHidden(true)
                        }

                        if let text = state.text {
                            Text(text)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .accessibilityHidden(state.hidesContentFromAccessibility)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if state.isActionVisible,
                   let actionTitle = state.actionTitle,
                   let action = state.action {
                    Button {
                        onAction(action)
                    } label: {
                        Text(actionTitle)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .foregroundColor(backgroundColor)
                            .cornerRadius(5)
                    }
                    .accessibilityFocused($isActionFocused)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                }

                Button(action: onExit) {
                    Text(state.exitTitle)
                        .font(.callout)
                        .frame(maxWidth: .infinity, minHeight: 45)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.isActionVisible)
        .onChange(of: state.actionFocusRequest) { _ in
            isActionFocused = true
        }
    }
}
