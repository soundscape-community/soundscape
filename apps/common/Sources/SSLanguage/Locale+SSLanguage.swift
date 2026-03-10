// Copyright (c) Soundscape Community Contributers.

import Foundation

public extension Locale {
    static let en = Locale(identifier: "en")
    static let enUS = Locale(identifier: "en-US")
    static let enGB = Locale(identifier: "en-GB")
    static let frFR = Locale(identifier: "fr-FR")

    static var preferredLocales: [Locale] {
        preferredLanguages.map { Locale(identifier: $0) }
    }

    var defaultEnglish: Locale {
        identifier == Locale.enUS.identifier ? Locale.enUS : Locale.enGB
    }

    var identifierHyphened: String {
        identifier.replacingOccurrences(of: "_", with: "-")
    }

    var localizedDescription: String {
        localizedDescription(with: self)
    }

    func localizedDescription(with locale: Locale, bundle: Bundle? = nil) -> String {
        guard
            let languageCode,
            let localizedLanguage = locale.localizedString(forLanguageCode: languageCode)?.capitalized(with: locale)
        else {
            return ""
        }

        guard
            let regionCode,
            let localizedCountry = locale.localizedString(forRegionCode: regionCode)
        else {
            return localizedLanguage
        }

        let bundle = bundle ?? LanguageLocalizer.moduleBundle
        return LanguageLocalizer.localizedString(
            "settings.language.language_name",
            arguments: [localizedLanguage, localizedCountry],
            locale: locale,
            bundle: bundle,
            normalizeArguments: true
        )
    }
}
