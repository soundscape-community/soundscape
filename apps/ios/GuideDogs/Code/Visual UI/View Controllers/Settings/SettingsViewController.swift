//
//  SettingsViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

struct SettingsScreen: View {
    @ObservedObject var navigation: AppNavigationModel
    @StateObject private var model = SettingsViewModel()

    var body: some View {
        SettingsView(model: model)
            .navigationTitle(GDLocalizedString("settings.screen_title"))
            .toolbar(.visible, for: .navigationBar)
            .onAppear {
                model.open = { [weak navigation] in navigation?.open(.settingsPage($0)) }
                model.objectWillChange.send()
                GDLogActionInfo("Opened 'Settings'")
            }
    }
}

final class SettingsViewModel: ObservableObject {
    enum Confirmation: String, Identifiable {
        case mediaControls, stopSharing

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mediaControls: return "general.alert.confirmation_title"
            case .stopSharing: return "settings.telemetry.optout.alert_title"
            }
        }

        var message: String {
            switch self {
            case .mediaControls: return "setting.audio.mix_with_others.confirmation"
            case .stopSharing: return "settings.telemetry.optout.alert_message"
            }
        }

        var action: String {
            switch self {
            case .mediaControls: return "settings.audio.mix_with_others.title"
            case .stopSharing: return "settings.telemetry.optout.action"
            }
        }
    }

    @Published var confirmation: Confirmation?
    var open: (SettingsRoute) -> Void = { _ in }

    private let settings = SettingsContext.shared

    var calloutsEnabled: Bool { settings.automaticCalloutsEnabled }
    var naviLensAutoSnooze: Binding<Bool> { binding(\.naviLensAutoSnoozeEnabled) }

    func binding(_ setting: ReferenceWritableKeyPath<SettingsContext, Bool>,
                 also related: [ReferenceWritableKeyPath<SettingsContext, Bool>] = []) -> Binding<Bool> {
        Binding {
            self.settings[keyPath: setting]
        } set: { isOn in
            self.objectWillChange.send()
            self.settings[keyPath: setting] = isOn
            for keyPath in related {
                self.settings[keyPath: keyPath] = isOn
            }
        }
    }

    var mediaControls: Binding<Bool> {
        Binding {
            !self.settings.audioSessionMixesWithOthers
        } set: { enabled in
            if enabled {
                self.confirmation = .mediaControls
            } else {
                self.setMediaControls(false)
            }
        }
    }

    var usageSharing: Binding<Bool> {
        Binding {
            GDATelemetry.enabled
        } set: { enabled in
            if enabled {
                self.setUsageSharing(true)
            } else {
                self.confirmation = .stopSharing
            }
        }
    }

    func confirm(_ confirmation: Confirmation) {
        switch confirmation {
        case .mediaControls: setMediaControls(true)
        case .stopSharing: setUsageSharing(false)
        }
    }

    private func setMediaControls(_ enabled: Bool) {
        objectWillChange.send()
        settings.audioSessionMixesWithOthers = !enabled
        AppContext.shared.audioEngine.mixWithOthers = !enabled
    }

    private func setUsageSharing(_ enabled: Bool) {
        objectWillChange.send()
        GDATelemetry.setConsent(sharingEnabled: enabled)
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavigationBanner()

            Form {
                Section(GDLocalizedString("settings.section.general")) {
                    row("settings.language.screen_title.2", .language)
                    row("settings.general.voice", .voice)
                    row("general.volume", .volume)
                    row("menu.devices", .devices)
                    row("siri_shortcuts.title.beta", .shortcuts)
                }

                Section {
                    row("beacon.audio_beacon", .beacon)
                } header: {
                    GDLocalizedTextView("beacon.audio_beacon")
                } footer: {
                    GDLocalizedTextView("beacon.settings.description")
                }

                Section(GDLocalizedString("menu.manage_callouts")) {
                    toggle("callouts.allow_callouts", "callouts.turn_on_off", model.binding(\.automaticCalloutsEnabled))
                    if model.calloutsEnabled {
                        toggle("callouts.places_and_landmarks", "callouts.places_and_landmarks.info",
                               model.binding(\.placeSenseEnabled, also: [\.landmarkSenseEnabled, \.informationSenseEnabled]))
                        toggle("callouts.mobility", "callouts.mobility.transportation_info",
                               model.binding(\.mobilitySenseEnabled, also: [\.safetySenseEnabled]))
                        toggle("callouts.intersections", "callouts.intersections.info", model.binding(\.intersectionSenseEnabled))
                        toggle("callouts.audio_beacon", "callouts.audio_beacon.info", model.binding(\.destinationSenseEnabled))
                        toggle("callouts.shake_callouts", "callouts.shake_callouts.info", model.binding(\.shakeCalloutsEnabled))
                    }
                }

                Section {
                    toggle("settings.audio.mix_with_others.title", nil, model.mediaControls)
                        .disabled(AppContext.shared.isRouteGuidanceActive)
                } header: {
                    GDLocalizedTextView("settings.audio.media_controls")
                } footer: {
                    GDLocalizedTextView("settings.audio.mix_with_others.description")
                }

                Section {
                    toggle("preview.include_unnamed_roads.title", nil, model.binding(\.previewIntersectionsIncludeUnnamedRoads))
                } header: {
                    GDLocalizedTextView("preview.title")
                } footer: {
                    GDLocalizedTextView("preview.include_unnamed_roads.subtitle")
                }

                Section {
                    toggle("settings.navilens.auto_snooze.title", nil, model.naviLensAutoSnooze)
                } header: {
                    GDLocalizedTextView("settings.section.navilens")
                } footer: {
                    GDLocalizedTextView("settings.navilens.auto_snooze.description")
                }

                Section(GDLocalizedString("settings.section.troubleshooting")) {
                    row("settings.section.troubleshooting", .troubleshooting)
                }

                Section(GDLocalizedString("settings.section.about")) {
                    row("settings.about_app", .about)
                }

                Section {
                    toggle("settings.section.share_usage_data", nil, model.usageSharing)
                } header: {
                    GDLocalizedTextView("settings.section.telemetry")
                } footer: {
                    GDLocalizedTextView("settings.section.telemetry.footer")
                }
            }
        }
        .alert(
            GDLocalizedString(model.confirmation?.title ?? "general.alert.confirmation_title"),
            isPresented: Binding(get: { model.confirmation != nil }, set: { if !$0 { model.confirmation = nil } }),
            presenting: model.confirmation
        ) { confirmation in
            Button(role: .cancel) { } label: { GDLocalizedTextView("general.alert.cancel") }
            Button(role: confirmation == .stopSharing ? .destructive : nil) {
                model.confirm(confirmation)
            } label: {
                GDLocalizedTextView(confirmation.action)
            }
        } message: { confirmation in
            GDLocalizedTextView(confirmation.message)
        }
    }

    private func row(_ title: String, _ destination: SettingsRoute) -> some View {
        Button {
            model.open(destination)
        } label: {
            HStack {
                GDLocalizedTextView(title)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ title: String, _ description: String?, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 4) {
                GDLocalizedTextView(title)
                if let description {
                    GDLocalizedTextView(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
