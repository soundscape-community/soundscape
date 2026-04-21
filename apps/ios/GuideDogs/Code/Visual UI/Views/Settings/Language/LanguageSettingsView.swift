//
//  LanguageSettingsView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct LanguageSettingsView: View {

    private let supportedLocales: [Locale]

    @State private var selectedLocale: Locale
    @State private var pendingLocale: Locale?
    @State private var unitPreference: UnitPreference

    private var confirmationTitle: String {
        guard let pendingLocale else {
            return ""
        }

        let localeName = pendingLocale.localizedDescription(with: selectedLocale)
        return GDLocalizedString("settings.language.change_alert", localeName)
    }

    init(
        supportedLocales: [Locale] = LocalizationContext.supportedLocales,
        selectedLocale: Locale = LocalizationContext.currentAppLocale,
        metricUnits: Bool = SettingsContext.shared.metricUnits
    ) {
        self.supportedLocales = supportedLocales
        _selectedLocale = State(initialValue: selectedLocale)
        _unitPreference = State(initialValue: UnitPreference(metricUnits: metricUnits))
    }

    var body: some View {
        List {
            Section(header: LanguageSettingsSectionHeader(text: GDLocalizedString("settings.section.units"))) {
                Picker(GDLocalizedString("settings.section.units"), selection: $unitPreference) {
                    ForEach(UnitPreference.allCases) { preference in
                        Text(GDLocalizedString(preference.titleKey)).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                .tint(.primaryForeground)
                .listRowBackground(Color.primaryBackground)
                .listRowSeparatorTint(Color.secondaryBackground)
            }

            Section(header: LanguageSettingsSectionHeader(text: GDLocalizedString("settings.language.screen_title"))) {
                ForEach(supportedLocales, id: \.identifierHyphened) { locale in
                    Button {
                        selectLocale(locale)
                    } label: {
                        LanguageSettingsLocaleRow(
                            locale: locale,
                            appLocale: selectedLocale,
                            isSelected: locale.identifierHyphened == selectedLocale.identifierHyphened
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.primaryBackground)
                    .listRowSeparatorTint(Color.secondaryBackground)
                }
            }
        }
        .languageSettingsListBackground()
        .background(Color.quaternaryBackground.ignoresSafeArea())
        .listStyle(PlainListStyle())
        .tint(.primaryForeground)
        .navigationTitle(GDLocalizedString("settings.language.screen_title.2"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: trackScreenView)
        .onChange(of: unitPreference, perform: updateUnitsPreference)
        .alert(
            confirmationTitle,
            isPresented: isShowingConfirmation,
            presenting: pendingLocale
        ) { pendingLocale in
            let localeName = pendingLocale.localizedDescription(with: selectedLocale)

            Button(GDLocalizedString("settings.language.change_alert_action", localeName)) {
                confirmLocaleChange(pendingLocale)
            }

            Button(GDLocalizedString("general.alert.cancel"), role: .cancel) {
                self.pendingLocale = nil
            }
        }
    }

    private var isShowingConfirmation: Binding<Bool> {
        Binding(
            get: { pendingLocale != nil },
            set: { isPresented in
                if !isPresented {
                    pendingLocale = nil
                }
            }
        )
    }

    private func selectLocale(_ locale: Locale) {
        guard locale.identifierHyphened != selectedLocale.identifierHyphened else {
            return
        }

        pendingLocale = locale
    }

    private func confirmLocaleChange(_ locale: Locale) {
        selectedLocale = locale
        pendingLocale = nil

        LocalizationContext.currentAppLocale = locale
        GDATelemetry.track("settings.language.first_launch.user_change", with: ["locale": locale.identifier])
        LaunchHelper.configureAppView(with: .main)
    }

    private func updateUnitsPreference(_ preference: UnitPreference) {
        SettingsContext.shared.metricUnits = preference == .metric

        GDATelemetry.track(
            "settings.units_of_measure",
            with: ["units": SettingsContext.shared.metricUnits ? "metric" : "imperial"]
        )
    }

    private func trackScreenView() {
        GDATelemetry.trackScreenView("settings.language")
    }
}

private extension LanguageSettingsView {
    enum UnitPreference: String, CaseIterable, Identifiable {
        case imperial
        case metric

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .imperial:
                return "settings.units.imperial"
            case .metric:
                return "settings.units.metric"
            }
        }

        init(metricUnits: Bool) {
            self = metricUnits ? .metric : .imperial
        }
    }
}

private struct LanguageSettingsSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.localizedUppercase)
            .font(.caption)
            .foregroundColor(.primaryForeground)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct LanguageSettingsLocaleRow: View {
    let locale: Locale
    let appLocale: Locale
    let isSelected: Bool

    private var title: String {
        locale.localizedDescription
    }

    private var subtitle: String? {
        let localizedSubtitle = locale.localizedDescription(with: appLocale)
        return localizedSubtitle == title ? nil : localizedSubtitle
    }

    private var titleText: some View {
        Text(titleAttributedString)
            .foregroundColor(.primaryForeground)
            .accessibleTextFormat()
    }

    private var titleAttributedString: AttributedString {
        var attributedString = AttributedString(title)
        attributedString.languageIdentifier = locale.identifierHyphened
        return attributedString
    }

    @ViewBuilder
    private var subtitleText: some View {
        if let subtitle {
            Text(subtitleAttributedString(subtitle))
                .font(.subheadline)
                .foregroundColor(.secondaryForeground)
                .accessibleTextFormat()
        }
    }

    private func subtitleAttributedString(_ subtitle: String) -> AttributedString {
        var attributedString = AttributedString(subtitle)
        attributedString.languageIdentifier = appLocale.identifierHyphened
        return attributedString
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                titleText
                    .frame(maxWidth: .infinity, alignment: .leading)

                if subtitle != nil {
                    subtitleText
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 12)

            if isSelected {
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
    }
}

private extension View {
    @ViewBuilder
    func languageSettingsListBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

struct LanguageSettingsView_Previews: PreviewProvider {
    static let locales = [
        Locale(identifier: "en_US"),
        Locale(identifier: "en_GB"),
        Locale(identifier: "es_ES"),
        Locale(identifier: "ja_JP")
    ]

    static var previews: some View {
        NavigationView {
            LanguageSettingsView(supportedLocales: locales, selectedLocale: locales[0], metricUnits: true)
        }
    }
}
