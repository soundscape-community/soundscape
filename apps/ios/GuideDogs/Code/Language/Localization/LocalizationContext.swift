//
//  LocalizationContext.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CocoaLumberjackSwift
import SwiftUI

public func GDLocalizedString(_ key: String) -> String {
    return LocalizationContext.localizedString(key)
}

public func GDLocalizedString(_ key: String, _ arguments: String...) -> String {
    return LocalizationContext.localizedString(key, arguments: arguments)
}

/// Returns the SwiftUI Text control for the given localized string key
public func GDLocalizedTextView(_ key: String) -> Text {
    return Text(GDLocalizedString(key))
}

/// Returns the SwiftUI Text control for the given localized string key
public func GDLocalizedTextView(_ key: String, _ arguments: String...) -> Text {
    return Text(LocalizationContext.localizedString(key, arguments: arguments))
}

/// Mark strings as non-localizable strings. These could be strings such as symbols or debug strings.
public func GDLocalizationUnnecessary(_ key: String) -> String {
    return key
}

#if FEATURE_FLAGS_ON
/// Marks feature-flag specific strings as requiring localization when the feature flag is removed.
public func GDFutureLocalizationRequired(_ key: String, string: String, comment: String) -> String {
    return string
}
#else
/// Marks feature-flag specific strings as requiring localization when the feature flag is removed.
@available(iOS, obsoleted: 11.0, message: "Feature flag specific strings must be localized when the feature flag is removed! Move this to Localizable.strings.")
public func GDFutureLocalizationRequired(_ key: String, string: String, comment: String) -> String {
    return string
}
#endif

/// Marks specific strings as requiring localization before releasing the app.
@available(iOS, deprecated: 11.0, message: "Strings must be localized before release! Move this to Localizable.strings.")
public func GDLocalizationRequired(_ string: String) -> String {
    return string
}

// MARK: -

extension Notification.Name {
    static let appLocaleDidChange = Notification.Name("GDAAppLocaleDidChange")
}

// MARK: -

class LocalizationContext {
    
    // MARK: Keys
    
    struct NotificationKeys {
        static let locale = "GDALocale"
    }
    
    // MARK: Computed Properties

    static let defaultLanguageCode = "en"
    static let defaultRegionCode = "US"
    static let supportedLocales = Bundle.main.locales
    
    static var deviceLocale: Locale {
        return Locale.current
    }
    
    /// The current app locale. This will return one of the following:
    /// 1. The user-selected app locale (if a valid selection has been made)
    /// 2. The localization selected by iOS from the user's preferred languages
    /// 3. The app's development locale
    static var currentAppLocale: Locale {
        get {
            return currentLocalization().locale
        }
        set(newLocale) {
            guard let bundle = Bundle(locale: newLocale) else {
                DDLogError("Localization error: Unsupported app locale \"\(newLocale.identifier)\"")
                return
            }

            localizationLock.lock()
            cachedLocalization = AppLocalization(locale: newLocale, bundle: bundle)
            localizationLock.unlock()

            SettingsContext.shared.locale = newLocale
            
            configureAccessibilityLanguage()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.appLocaleDidChange,
                                                object: self,
                                                userInfo: [NotificationKeys.locale: newLocale])
            }
        }
    }

    private struct AppLocalization {
        let locale: Locale
        let bundle: Bundle
    }

    private static let localizationLock = NSLock()
    private static var cachedLocalization: AppLocalization?
    
    static var currentLanguageCode: String {
        return currentAppLocale.languageCode ?? defaultLanguageCode
    }
    
    static var currentRegionCode: String {
        return currentAppLocale.regionCode ?? defaultRegionCode
    }
    
    /// The development app locale ("en-US")
    static let developmentLocale = Bundle.main.developmentLocale ?? Locale.enUS

    static private let defaultDevelopmentBundle = Bundle(locale: developmentLocale)!

    private static func currentLocalization() -> AppLocalization {
        let developmentBundle = defaultDevelopmentBundle

        localizationLock.lock()
        defer { localizationLock.unlock() }

        if let cachedLocalization {
            return cachedLocalization
        }

        let locale = resolveAppLocale(
            selectedLocale: SettingsContext.shared.locale,
            supportedLocales: supportedLocales,
            preferredLocalization: Bundle.main.preferredLocalizations.first,
            developmentLocalization: Bundle.main.developmentLocalization
        )
        let localization = AppLocalization(
            locale: locale,
            bundle: Bundle(locale: locale) ?? developmentBundle
        )
        cachedLocalization = localization

        return localization
    }

    static func resolveAppLocale(
        selectedLocale: Locale?,
        supportedLocales: [Locale],
        preferredLocalization: String?,
        developmentLocalization: String?
    ) -> Locale {
        if let selectedLocale,
           let supportedLocale = supportedLocale(matching: selectedLocale.identifier, in: supportedLocales) {
            return supportedLocale
        }

        if let preferredLocalization,
           let supportedLocale = supportedLocale(matching: preferredLocalization, in: supportedLocales) {
            return supportedLocale
        }

        if let developmentLocalization {
            return supportedLocale(matching: developmentLocalization, in: supportedLocales)
                ?? Locale(identifier: developmentLocalization)
        }

        return Locale.enUS
    }

    private static func supportedLocale(matching identifier: String, in supportedLocales: [Locale]) -> Locale? {
        let normalizedIdentifier = Locale(identifier: identifier).identifierHyphened.lowercased()
        return supportedLocales.first {
            $0.identifierHyphened.lowercased() == normalizedIdentifier
        }
    }
    
    // MARK: Properties
    
    /// Stores the current localized string debug options, such as double length, accented, etc.
    private static let stringDebugOptions = ProcessInfo.processInfo.stringDebugOptions
    
    /// In order to test string localization with `NSLocalizedString()`, we use a default input value (such as "NOT LOCALIZED")
    /// to be returned when a localized key is not found.
    private static let localizedStringNotFoundInput = "NOT LOCALIZED"
    
    /// When running the app with debug launch arguments, such as bounded strings ("[# NOT LOCALIZED #]") or accented strings
    /// ("ǸO̧T̀ L̊O̧ÇÄL̊I̧Z̀E̥D̃"), localized strings returned from `NSLocalizedString()` will be transformed appropriately.
    /// In order to detect non-localized keys, we compare the returned value from `NSLocalizedString()` to the transformed
    /// version of `localizedStringNotFoundInput`, which this value stores.
    /// - Example: Default input value to `NSLocalizedString()` is "NOT LOCALIZED". Using the `.bounded` debug option,
    /// the returned value will be "[# NOT LOCALIZED #]".
    private static let localizedStringNotFoundOutput = localizedStringNotFoundInput.transform(with: stringDebugOptions)

    // MARK: Localize Strings
    
    static func localizedString(_ key: String, arguments: [String]) -> String {
        guard !key.isEmpty else {
            DDLogWarn("Localized string error: key is nil")
            return key
        }
        
        // In development, localized strings can change, with the number of arguments. For example:
        // In the base English language we change "Waypoint %@" to "Waypoint %1$@ of %2$@".
        // If the base file changed, but a translation file did not, and is using a different number
        // of arguments, we could experience a crash.
        // This avoids the problem by addig/removing the needed arguments.
        // If release, we expect all strings should be translated with the same number of arguments.
        guard BuildSettings.source == .appStore else {
            return String(normalizedArgsWithFormat: localizedString(key), arguments: arguments)
        }
        
        return String(format: localizedString(key), arguments: arguments)
    }
    
    static func localizedString(_ key: String) -> String {
        guard !key.isEmpty else {
            DDLogWarn("Localized string error: key is nil")
            return key
        }

        let localization = currentLocalization()

        return localizedString(
            key,
            bundle: localization.bundle,
            fallbackBundle: defaultDevelopmentBundle
        )
    }

    static func localizedString(_ key: String, bundle: Bundle, fallbackBundle: Bundle) -> String {
        guard !key.isEmpty else {
            DDLogWarn("Localized string error: key is nil")
            return key
        }

        let fallback: String
        if let developmentString = nsLocalizedString(key, bundle: fallbackBundle) {
            fallback = developmentString
        } else {
            DDLogWarn("Localization error: Localized string not found for key \"\(key)\"")
            fallback = key
        }

        return NSLocalizedString(
            key,
            bundle: bundle,
            value: fallback,
            comment: ""
        )
    }
    
    /// Returns the localized string using the native `NSLocalizedString` function,
    /// or `nil` if it does not exists
    private static func nsLocalizedString(_ key: String, bundle: Bundle) -> String? {
        guard !key.isEmpty else {
            DDLogWarn("Localized string error: key is nil")
            return nil
        }
        
        let localizedString = NSLocalizedString(key,
                                                bundle: bundle,
                                                value: localizedStringNotFoundInput,
                                                comment: "")
        
        guard localizedString != localizedStringNotFoundOutput else {
            return nil
        }
        
        return localizedString
    }
    
}

extension LocalizationContext {
    static func localizedStringExists(_ key: String, locale: Locale) -> Bool {
        guard let bundle = Bundle(locale: locale) else { return false }
        
        let localizedString = NSLocalizedString(key,
                                                bundle: bundle,
                                                value: localizedStringNotFoundInput,
                                                comment: "")
        
        return localizedString != localizedStringNotFoundOutput
    }
}

extension LocalizationContext {
    /// Set the accessibility (VoiceOver) language to the current current app locale
    static func configureAccessibilityLanguage() {
        if let languageCode = LocalizationContext.currentAppLocale.languageCode {
            UIApplication.shared.accessibilityLanguage = languageCode
        }
    }
}

extension String {
    func lowercasedWithAppLocale() -> String {
        return self.lowercased(with: LocalizationContext.currentAppLocale)
    }
    
    func uppercasedWithAppLocale() -> String {
        return self.uppercased(with: LocalizationContext.currentAppLocale)
    }
}

extension Bundle {
    var locales: [Locale] {
        return self.localizations.map { Locale(identifier: $0) }.sorted { $0.identifier < $1.identifier }
    }
    
    var developmentLocale: Locale? {
        guard let developmentLocalization = self.developmentLocalization else { return nil }
        return Locale(identifier: developmentLocalization)
    }
    
    convenience init?(locale: Locale) {
        // Locales with a region have identifiers with an underscore ("en_US"), while folders have names with a dash ("en-US").
        guard let bundlePath = Bundle.main.path(forResource: locale.identifierHyphened, ofType: "lproj") else { return nil }
        self.init(path: bundlePath)
    }
}

extension Locale {
    /// The locale for English (United States)
    static let enUS = Locale(identifier: "en-US")
    
    /// Locale for French (France)
    static let frFr = Locale(identifier: "fr-FR")
    
    /// Returns the identifier with a hyphen ("-"), if an underscore ("_") is used, e.g. "en_US" -> "en-US".
    ///
    /// Information about locale identifiers:
    /// * Use an underscore character to combine a language ID with a region designator, i.e. "en_GB".
    /// * Use a hyphen character to combine a language ID with a script designator, i.e. "zh-Hans".
    ///
    /// In some cases, such as `Bundle.main.localizations`, the returned language IDs are not proparly formatted,
    /// so we can use this property to re-format locale identifiers with hyphens.
    /// - seealso: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html
    var identifierHyphened: String {
        return self.identifier.replacingOccurrences(of: "_", with: "-")
    }
    
    /// Returns the description for the current locale. E.g. "en-US" is "English (United States)"
    var localizedDescription: String {
        return localizedDescription(with: self)
    }
    
    /// Returns the description for the current locale. E.g. "en-US" is "English (United States)"
    func localizedDescription(with locale: Locale) -> String {
        guard let languageCode = self.languageCode,
            let localizedLanguage = locale.localizedString(forLanguageCode: languageCode)?.capitalized(with: locale) else {
                return ""
        }
        
        guard let regionCode = self.regionCode,
            let localizedCountry = locale.localizedString(forRegionCode: regionCode) else {
                return localizedLanguage
        }
        
        return GDLocalizedString("settings.language.language_name", localizedLanguage, localizedCountry) // "English (United Kingdom)"
    }
}
