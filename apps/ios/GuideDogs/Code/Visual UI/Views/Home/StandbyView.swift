//
//  StandbyView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct StandbyView: View {
    let onSleep: () -> Void
    let onWake: () -> Void
    @State private var didSleep = false
    @State private var isSnoozing = false
    @AccessibilityFocusState private var titleIsFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .footnote) private var buttonDiameter = 120.0

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                GDLocalizedTextView(isSnoozing ? "sleep.snoozing" : "sleep.sleeping")
                    .font(.title)
                    .padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)

                Image(isSnoozing ? "snooze_Illustration" : "sleeping_Illustration")
                    .accessibilityHidden(true)

                GDLocalizedTextView(isSnoozing ? "sleep.snoozing.message" : "sleep.sleeping.message")

                ViewThatFits(in: .horizontal) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: 20) { wakeControls }
                    }
                    VStack(spacing: 16) { wakeControls }
                }
                .buttonStyle(.plain)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
        }
        .foregroundStyle(.white)
        .background {
            Color.black
                .overlay {
                    Image("Background")
                        .resizable()
                        .opacity(0.8)
                }
                .ignoresSafeArea()
        }
        .accessibilityIgnoresInvertColors()
        .onReceive(NotificationCenter.default.publisher(for: .appOperationStateDidChange)
            .receive(on: DispatchQueue.main)) { _ in
            if AppContext.shared.state == .normal { onWake() }
        }
        .onAppear {
            guard !didSleep else { return }
            didSleep = true
            onSleep()
            titleIsFocused = true
        }
    }

    @ViewBuilder
    private var wakeControls: some View {
        if !isSnoozing {
            wakeButton(
                title: "sleep.ui.wake_on_leave",
                accessibilityTitle: "sleep.wake_up_when_i_leave",
                artwork: "WOL_button withoutText",
                foreground: Color.quaternaryBackground,
                background: .white
            ) {
                AppContext.shared.snooze()
                isSnoozing = AppContext.shared.state == .snooze
                titleIsFocused = true
            }
        }

        wakeButton(
            title: "sleep.ui.wake_up_now",
            accessibilityTitle: "sleep.wake_up_now",
            artwork: "WUN_button withoutText",
            foreground: Color.secondaryForeground,
            background: Color.secondaryBackground
        ) {
            AppContext.shared.wakeUp()
        }
    }

    private func wakeButton(
        title: String,
        accessibilityTitle: String,
        artwork: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if dynamicTypeSize.isAccessibilitySize {
                GDLocalizedTextView(title)
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(background, in: RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
            } else {
                GDLocalizedTextView(title)
                    .font(.footnote)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.bottom, buttonDiameter * 0.16)
                    .frame(width: buttonDiameter, height: buttonDiameter, alignment: .bottom)
                    .background {
                        Image(artwork).resizable().accessibilityHidden(true)
                    }
                    .contentShape(Circle())
            }
        }
        .foregroundStyle(foreground)
        .accessibilityLabel(GDLocalizedTextView(accessibilityTitle))
    }
}
