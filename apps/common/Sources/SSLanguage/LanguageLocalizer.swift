// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum LanguageLocalizer {
    private static let localizedStringNotFoundInput = "NOT LOCALIZED"
    public static var moduleBundle: Bundle { .module }

    public static func localizedString(
        _ key: String,
        locale: Locale,
        bundle: Bundle? = nil,
        fallbackLocale: Locale? = nil
    ) -> String {
        guard !key.isEmpty else {
            return key
        }

        let bundle = bundle ?? moduleBundle

        if let localized = nsLocalizedString(key, locale: locale, bundle: bundle) {
            return localized
        }

        let fallbackLocales = [fallbackLocale, locale.defaultEnglish, bundle.developmentLocale]
            .compactMap { $0 }
            .filter { $0.identifier != locale.identifier }

        for fallback in fallbackLocales {
            if let localized = nsLocalizedString(key, locale: fallback, bundle: bundle) {
                return localized
            }
        }

        return key
    }

    public static func localizedString(
        _ key: String,
        arguments: [String],
        locale: Locale,
        bundle: Bundle? = nil,
        fallbackLocale: Locale? = nil,
        normalizeArguments: Bool = false
    ) -> String {
        let bundle = bundle ?? moduleBundle
        let format = localizedString(
            key,
            locale: locale,
            bundle: bundle,
            fallbackLocale: fallbackLocale
        )

        if normalizeArguments {
            return String(normalizedArgsWithFormat: format, arguments: arguments)
        }

        return String(format: format, arguments: arguments)
    }

    public static func localizedStringExists(
        _ key: String,
        locale: Locale,
        bundle: Bundle? = nil
    ) -> Bool {
        let bundle = bundle ?? moduleBundle
        return nsLocalizedString(key, locale: locale, bundle: bundle) != nil
    }

    private static func nsLocalizedString(
        _ key: String,
        locale: Locale,
        bundle: Bundle
    ) -> String? {
        guard !key.isEmpty else {
            return nil
        }

        let localizedString = NSLocalizedString(
            key,
            bundle: bundle.languageBundle(for: locale) ?? bundle,
            value: localizedStringNotFoundInput,
            comment: ""
        )

        return localizedString == localizedStringNotFoundInput ? nil : localizedString
    }
}
