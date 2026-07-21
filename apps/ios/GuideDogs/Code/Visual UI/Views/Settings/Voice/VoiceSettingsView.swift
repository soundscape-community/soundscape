//
//  VoiceSettingsView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import SwiftUI

struct VoiceSettingsView: View {
    @StateObject private var model = VoiceSettingsModel()
    @AccessibilityFocusState private var focusedVoiceIdentifier: String?

    var body: some View {
        List {
            Section {
                EmptyView()
            } footer: {
                Text(model.additionalVoicesGuidance)
                    .foregroundColor(.secondaryForeground)
            }

            Section(header: VoiceSettingsSectionHeader(text: GDLocalizedString("voice.settings.speaking_rate"))) {
                VoiceSettingsSpeakingRateSlider(
                    speakingRate: $model.speakingRate,
                    onEditingChanged: model.speakingRateEditingChanged
                )
                .listRowBackground(Color.primaryBackground)
                .listRowSeparatorTint(Color.secondaryBackground)
            }

            voiceSection(
                title: model.currentLanguageSectionTitle,
                voices: model.voicesInCurrentLanguage
            )

            voiceSection(
                title: GDLocalizedString("voice.apple.other_languages"),
                voices: model.voicesInOtherLanguages
            )
        }
        .voiceSettingsListBackground()
        .background(Color.quaternaryBackground.ignoresSafeArea())
        .listStyle(PlainListStyle())
        .tint(.primaryForeground)
        .navigationTitle(GDLocalizedString("settings.general.voice"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: model.screenDidAppear)
        .onDisappear(perform: model.screenDidDisappear)
        .onReceive(NotificationCenter.default.publisher(for: .appWillEnterForeground)) { _ in
            model.appWillEnterForeground()
        }
        .onChange(of: model.voiceToFocus) { voiceIdentifier in
            focusedVoiceIdentifier = voiceIdentifier
        }
        .alert(
            GDLocalizedString("voice.settings.enhanced_available.title"),
            isPresented: isShowingEnhancedVoiceAlert
        ) {
            Button(GDLocalizedString("voice.settings.enhanced_available.button")) {
                model.confirmEnhancedVoiceSelection()
            }

            Button(GDLocalizedString("general.alert.cancel"), role: .cancel) {
                model.cancelEnhancedVoiceSelection()
            }
        } message: {
            Text(GDLocalizedString("voice.settings.enhanced_available"))
        }
    }

    private var isShowingEnhancedVoiceAlert: Binding<Bool> {
        Binding(
            get: { model.pendingEnhancedVoiceIdentifier != nil },
            set: { isPresented in
                if !isPresented {
                    model.cancelEnhancedVoiceSelection()
                }
            }
        )
    }

    private func voiceSection(title: String, voices: [AVSpeechSynthesisVoice]) -> some View {
        Section(header: VoiceSettingsSectionHeader(text: title)) {
            ForEach(voices, id: \.identifier) { voice in
                Button {
                    model.selectVoice(voice)
                } label: {
                    VoiceSettingsVoiceRow(
                        voice: voice,
                        subtitle: model.detail(for: voice),
                        isSelected: model.selectedVoiceIdentifier == voice.identifier,
                        isPreviewing: model.previewingVoiceIdentifier == voice.identifier
                    )
                }
                .buttonStyle(.plain)
                .accessibilityFocused($focusedVoiceIdentifier, equals: voice.identifier)
                .listRowBackground(Color.primaryBackground)
                .listRowSeparatorTint(Color.secondaryBackground)
            }
        }
    }
}

private struct VoiceSettingsSpeakingRateSlider: View {
    @Binding var speakingRate: Float
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        Slider(
            value: $speakingRate,
            in: 0.0 ... 1.0,
            onEditingChanged: onEditingChanged,
            minimumValueLabel: Image(systemName: "tortoise")
                .accessibilityHidden(true),
            maximumValueLabel: Image(systemName: "hare")
                .accessibilityHidden(true),
            label: {
                GDLocalizedTextView("voice.settings.speaking_rate")
            }
        )
        .tint(.secondaryForeground)
        .accessibilityLabel(GDLocalizedTextView("voice.settings.speaking_rate"))
    }
}

@MainActor
private final class VoiceSettingsModel: ObservableObject {
    @Published private(set) var voicesInCurrentLanguage: [AVSpeechSynthesisVoice] = []
    @Published private(set) var voicesInOtherLanguages: [AVSpeechSynthesisVoice] = []
    @Published private(set) var selectedVoiceIdentifier: String?
    @Published private(set) var defaultVoiceIdentifier: String?
    @Published private(set) var previewingVoiceIdentifier: String?
    @Published private(set) var pendingEnhancedVoiceIdentifier: String?
    @Published private(set) var voiceToFocus: String?
    @Published var speakingRate: Float

    private let currentLocale = LocalizationContext.currentAppLocale
    private var didMuteCallouts = false
    private var didMuteBeacon = false
    private var isScreenVisible = false
    private var previewTask: Task<Void, Never>?
    private var rateAnnouncementTask: Task<Void, Never>?

    var additionalVoicesGuidance: String {
        "\(GDLocalizedString("voice.apple.additional")) \(GDLocalizedString("voice.apple.no_siri"))"
    }

    var currentLanguageSectionTitle: String {
        guard let languageCode = currentLocale.languageCode else {
            return currentLocale.localizedDescription
        }

        return currentLocale.localizedString(forLanguageCode: languageCode) ?? currentLocale.localizedDescription
    }

    init() {
        speakingRate = SettingsContext.shared.speakingRate
        resetDeletedSelectedVoiceIfNeeded()
        reloadVoices()
    }

    func screenDidAppear() {
        guard !isScreenVisible else {
            return
        }

        isScreenVisible = true
        GDATelemetry.trackScreenView("settings.voice")

        let destinationManager = AppContext.shared.spatialDataContext.destinationManager
        if destinationManager.isAudioEnabled {
            didMuteBeacon = true
            destinationManager.toggleDestinationAudio(false)
        }

        if SettingsContext.shared.automaticCalloutsEnabled {
            didMuteCallouts = true
            SettingsContext.shared.automaticCalloutsEnabled = false
            AppContext.shared.eventProcessor.hush(playSound: false)
        }
    }

    func screenDidDisappear() {
        guard isScreenVisible else {
            return
        }

        isScreenVisible = false
        cancelPendingAudio()

        let destinationManager = AppContext.shared.spatialDataContext.destinationManager
        if didMuteBeacon, !destinationManager.isAudioEnabled {
            destinationManager.toggleDestinationAudio(false)
        }

        if didMuteCallouts, !SettingsContext.shared.automaticCalloutsEnabled {
            SettingsContext.shared.automaticCalloutsEnabled = true
        }

        didMuteBeacon = false
        didMuteCallouts = false
    }

    func appWillEnterForeground() {
        resetDeletedSelectedVoiceIfNeeded()
        reloadVoices()
    }

    func selectVoice(_ voice: AVSpeechSynthesisVoice) {
        guard voice.hasEnhancedVersion(), selectedVoiceIdentifier != voice.identifier else {
            commitVoiceSelection(voice)
            return
        }

        guard !voice.hasEnhancedVersionDownloaded() else {
            commitVoiceSelection(voice)
            return
        }

        pendingEnhancedVoiceIdentifier = voice.identifier
    }

    func confirmEnhancedVoiceSelection() {
        guard let identifier = pendingEnhancedVoiceIdentifier,
              let voice = voice(withIdentifier: identifier) else {
            pendingEnhancedVoiceIdentifier = nil
            return
        }

        pendingEnhancedVoiceIdentifier = nil
        commitVoiceSelection(voice)
    }

    func cancelEnhancedVoiceSelection() {
        pendingEnhancedVoiceIdentifier = nil
    }

    func speakingRateEditingChanged(_ isEditing: Bool) {
        guard !isEditing else {
            return
        }

        SettingsContext.shared.speakingRate = speakingRate
        announceSpeakingRateTest()

        GDATelemetry.track(
            "settings.voice.rate",
            with: [
                "value": String(speakingRate),
                "voice": SettingsContext.shared.voiceId ?? "not_set"
            ]
        )
    }

    func detail(for voice: AVSpeechSynthesisVoice) -> String {
        var detail = ""
        let voiceLocale = Locale(identifier: voice.language)

        if voiceLocale.languageCode != currentLocale.languageCode {
            detail = voiceLocale.localizedDescription
        } else if let regionCode = voiceLocale.regionCode {
            detail = voiceLocale.localizedString(forRegionCode: regionCode) ?? ""
        }

        guard voice.identifier == defaultVoiceIdentifier else {
            return detail
        }

        return GDLocalizedString("voice.apple.default", detail)
            .trimmingCharacters(in: .whitespaces)
    }

    private func resetDeletedSelectedVoiceIfNeeded() {
        if let identifier = SettingsContext.shared.voiceId {
            if AVSpeechSynthesisVoice(identifier: identifier) == nil {
                SettingsContext.shared.voiceId = nil
                selectedVoiceIdentifier = TTSConfigHelper.defaultVoice(forLocale: currentLocale)?.identifier
                defaultVoiceIdentifier = selectedVoiceIdentifier
            } else {
                selectedVoiceIdentifier = identifier
                defaultVoiceIdentifier = nil
            }
        } else {
            selectedVoiceIdentifier = TTSConfigHelper.defaultVoice(forLocale: currentLocale)?.identifier
            defaultVoiceIdentifier = selectedVoiceIdentifier
        }
    }

    private func reloadVoices() {
        voicesInCurrentLanguage = TTSConfigHelper.loadVoices(
            forCurrentLanguage: true,
            currentLocale: currentLocale
        )
        voicesInOtherLanguages = TTSConfigHelper.loadVoices(
            forCurrentLanguage: false,
            currentLocale: currentLocale
        )
    }

    private func voice(withIdentifier identifier: String) -> AVSpeechSynthesisVoice? {
        (voicesInCurrentLanguage + voicesInOtherLanguages).first { $0.identifier == identifier }
    }

    private func commitVoiceSelection(_ voice: AVSpeechSynthesisVoice) {
        previewTask?.cancel()
        rateAnnouncementTask?.cancel()
        voiceToFocus = nil
        defaultVoiceIdentifier = nil
        previewingVoiceIdentifier = voice.identifier
        selectedVoiceIdentifier = voice.identifier
        SettingsContext.shared.voiceId = voice.identifier

        AppContext.shared.eventProcessor.hush()

        previewTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }

            guard let self,
                  !Task.isCancelled,
                  self.isScreenVisible,
                  self.previewingVoiceIdentifier == voice.identifier else {
                return
            }

            GDATelemetry.track("settings.voice.preview", with: ["voice": voice.name])
            AppContext.process(TTSVoicePreviewEvent(name: voice.name) { [weak self] _ in
                Task { @MainActor in
                    self?.voicePreviewDidFinish(identifier: voice.identifier)
                }
            })
        }

        GDATelemetry.track("settings.voice.select", with: ["voice": voice.name])
        GDLogAppInfo("Selected voice: \(voice.name) (ID: \(voice.identifier))")
    }

    private func voicePreviewDidFinish(identifier: String) {
        guard isScreenVisible, previewingVoiceIdentifier == identifier else {
            return
        }

        previewingVoiceIdentifier = nil
        voiceToFocus = identifier
        GDLogAppVerbose("Updated VO focus on selected voice")
    }

    private func announceSpeakingRateTest() {
        rateAnnouncementTask?.cancel()

        guard UIAccessibility.isVoiceOverRunning else {
            playSpeakingRateTest()
            return
        }

        rateAnnouncementTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled, self?.isScreenVisible == true else {
                return
            }

            self?.playSpeakingRateTest()
        }
    }

    private func playSpeakingRateTest() {
        AppContext.shared.eventProcessor.hush(playSound: false)
        AppContext.shared.audioEngine.stopDiscrete()
        AppContext.process(GenericAnnouncementEvent(GDLocalizedString("voice.voice_rate_test")))
    }

    private func cancelPendingAudio() {
        previewTask?.cancel()
        previewTask = nil
        rateAnnouncementTask?.cancel()
        rateAnnouncementTask = nil
        pendingEnhancedVoiceIdentifier = nil
        voiceToFocus = nil

        if previewingVoiceIdentifier != nil {
            previewingVoiceIdentifier = nil
            AppContext.shared.eventProcessor.hush(playSound: false)
            AppContext.shared.audioEngine.stopDiscrete()
        }
    }
}

private struct VoiceSettingsSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.localizedUppercase)
            .font(.caption)
            .foregroundColor(.primaryForeground)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct VoiceSettingsVoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let subtitle: String
    let isSelected: Bool
    let isPreviewing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedVoiceName)
                    .foregroundColor(.primaryForeground)
                    .accessibleTextFormat()
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !subtitle.isEmpty {
                    Text(localizedSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryForeground)
                        .accessibleTextFormat()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 12)

            if isPreviewing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.primaryForeground)
                    .accessibilityHidden(true)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.primaryForeground)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6.0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(GDLocalizedTextView("voice.apple.preview_hint"))
    }

    private var localizedVoiceName: AttributedString {
        var name = AttributedString(voice.name)
        name.languageIdentifier = voice.language
        return name
    }

    private var localizedSubtitle: AttributedString {
        var localizedSubtitle = AttributedString(subtitle)
        localizedSubtitle.languageIdentifier = LocalizationContext.currentAppLocale.identifierHyphened
        return localizedSubtitle
    }
}

private extension View {
    @ViewBuilder
    func voiceSettingsListBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
