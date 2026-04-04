//
//  LanguageSettingsView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
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
        ZStack {
            Color.quaternaryBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    TableHeaderCell(text: GDLocalizedString("settings.section.units"))

                    LanguageSettingsUnitsRow(unitPreference: $unitPreference)

                    TableHeaderCell(text: GDLocalizedString("settings.language.screen_title"))

                    ForEach(Array(supportedLocales.enumerated()), id: \.element.identifierHyphened) { index, locale in
                        Button {
                            selectLocale(locale)
                        } label: {
                            LanguageSettingsLocaleRow(
                                locale: locale,
                                appLocale: selectedLocale,
                                isSelected: locale.identifierHyphened == selectedLocale.identifierHyphened,
                                showsDivider: index < supportedLocales.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(GDLocalizedString("settings.language.screen_title.2"))
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

private struct LanguageSettingsUnitsRow: View {
    @Binding var unitPreference: LanguageSettingsView.UnitPreference

    var body: some View {
        Picker(GDLocalizedString("settings.section.units"), selection: $unitPreference) {
            ForEach(LanguageSettingsView.UnitPreference.allCases) { preference in
                Text(GDLocalizedString(preference.titleKey)).tag(preference)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color.primaryBackground)
        .accessibilityLabel(GDLocalizedTextView("settings.section.units"))
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

private struct LanguageSettingsLocaleRow: View {
    let locale: Locale
    let appLocale: Locale
    let isSelected: Bool
    let showsDivider: Bool

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
                .foregroundColor(Color.secondaryForeground)
                .accessibleTextFormat()
        }
    }

    private func subtitleAttributedString(_ subtitle: String) -> AttributedString {
        var attributedString = AttributedString(subtitle)
        attributedString.languageIdentifier = appLocale.identifierHyphened
        return attributedString
    }

    var body: some View {
        VStack(spacing: 0) {
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
                        .foregroundColor(Color.primaryForeground)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primaryBackground)

            if showsDivider {
                Divider()
                    .background(Color.tertiaryBackground)
                    .padding(.horizontal, 8)
            }
        }
        .contentShape(Rectangle())
        .background(Color.primaryBackground)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
