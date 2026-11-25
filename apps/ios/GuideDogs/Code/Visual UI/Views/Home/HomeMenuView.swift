// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI

enum HomeMenuItem: CaseIterable {
    case devices, recreation, gpxRecording, settings, help, feedback, rate, share

    var title: String {
        switch self {
        case .devices: return "menu.devices"
        case .recreation: return "menu.events"
        case .gpxRecording: return "gpx_recording.title"
        case .settings: return "settings.screen_title"
        case .help: return "menu.help_and_tutorials"
        case .feedback: return "menu.send_feedback"
        case .rate: return "menu.rate"
        case .share: return "share.title"
        }
    }

    var icon: Image {
        switch self {
        case .devices: return Image("baseline-headset-28px")
        case .recreation: return Image("nordic_walking_white_28dp")
        case .gpxRecording: return Image(systemName: "record.circle")
        case .settings: return Image("ic_settings_28px")
        case .help: return Image("ic_help_outline_28px")
        case .feedback: return Image("ic_email_28px")
        case .rate: return Image("ic_star_rate_28px")
        case .share: return Image(systemName: "square.and.arrow.up")
        }
    }

    var route: AppRoute? {
        switch self {
        case .devices: return .devices
        case .recreation: return .recreation
        case .gpxRecording: return .gpxRecording
        case .settings: return .settings
        case .help: return .help
        case .feedback, .rate, .share: return nil
        }
    }
}

struct HomeMenuView: View {
    let close: () -> Void
    let select: (HomeMenuItem) -> Void

    @AccessibilityFocusState private var closeFocused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            Button(action: close) {
                Image("ic_chevron_left_28px")
                    .frame(minWidth: 60, minHeight: 56, alignment: .leading)
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(GDLocalizedTextView("ui.menu.close"))
            .accessibilityFocused($closeFocused)
            .keyboardShortcut(.cancelAction)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(HomeMenuItem.allCases.enumerated()), id: \.element) { index, item in
                        Button {
                            select(item)
                        } label: {
                            HStack(spacing: 16) {
                                item.icon
                                    .frame(width: 30)
                                    .accessibilityHidden(true)
                                GDLocalizedTextView(item.title)
                                    .font(.title3)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .background(dynamicTypeSize.isAccessibilitySize && index.isMultiple(of: 2) ? Color.menuAltBackground : .clear)
                    }
                }
            }

            Button {
                GDLogAppInfo("Play crosscheck audio")
                AppContext.process(CheckAudioEvent())
            } label: {
                GDLocalizedTextView("troubleshooting.check_audio")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.primaryBackground, in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
            }
            .accessibilityHint(GDLocalizedTextView("troubleshooting.check_audio.hint"))
            .padding(.horizontal, 12)
        }
        .padding(.top, 16)
        .foregroundStyle(Color.primaryForeground)
        .buttonStyle(.plain)
        .background {
            if reduceTransparency {
                Color.tertiaryBackground.ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(.black.opacity(0.2))
                    .ignoresSafeArea()
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
        .accessibilityIgnoresInvertColors()
        .onAppear { closeFocused = true }
    }
}
