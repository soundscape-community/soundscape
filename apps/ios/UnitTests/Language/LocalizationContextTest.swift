//
//  LocalizationContextTest.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

final class LocalizationContextTest: XCTestCase {
    private let supportedLocales = [
        Locale(identifier: "en-US"),
        Locale(identifier: "es-ES"),
        Locale(identifier: "es-419")
    ]

    func testSelectedAppLocaleOverridesSystemPreference() {
        let locale = LocalizationContext.resolveAppLocale(
            selectedLocale: Locale(identifier: "es-ES"),
            supportedLocales: supportedLocales,
            preferredLocalization: "es-419",
            developmentLocalization: "en-US"
        )

        XCTAssertEqual(locale.identifierHyphened, "es-ES")
    }

    func testSystemPreferenceIsUsedWithoutAppSelection() {
        let locale = LocalizationContext.resolveAppLocale(
            selectedLocale: nil,
            supportedLocales: supportedLocales,
            preferredLocalization: "es-419",
            developmentLocalization: "en-US"
        )

        XCTAssertEqual(locale.identifierHyphened, "es-419")
    }

    func testUnsupportedAppSelectionUsesSystemPreference() {
        let locale = LocalizationContext.resolveAppLocale(
            selectedLocale: Locale(identifier: "cy-GB"),
            supportedLocales: supportedLocales,
            preferredLocalization: "es-419",
            developmentLocalization: "en-US"
        )

        XCTAssertEqual(locale.identifierHyphened, "es-419")
    }

    func testDevelopmentLocalizationIsFinalLocaleFallback() {
        let locale = LocalizationContext.resolveAppLocale(
            selectedLocale: nil,
            supportedLocales: supportedLocales,
            preferredLocalization: nil,
            developmentLocalization: "en-US"
        )

        XCTAssertEqual(locale.identifierHyphened, "en-US")
    }

    func testFoundationSelectsExpectedSpanishLocalization() {
        let availableLocalizations = supportedLocales.map(\.identifierHyphened)
        let expectedLocalizations = [
            "es-US": "es-419",
            "es-MX": "es-419",
            "es-AR": "es-419",
            "es-ES": "es-ES",
            "es": "es-ES"
        ]

        for (preference, expectedLocalization) in expectedLocalizations {
            let localization = Bundle.preferredLocalizations(
                from: availableLocalizations,
                forPreferences: [preference]
            ).first

            XCTAssertEqual(localization, expectedLocalization, "Unexpected localization for \(preference)")
        }
    }

    func testLocalizedStringUsesDevelopmentFallback() throws {
        let activeBundle = try makeLocalizationBundle(strings: [
            "translated": "Traducción"
        ])
        let developmentBundle = try makeLocalizationBundle(strings: [
            "translated": "Translation",
            "missing_in_active": "English fallback"
        ])
        defer {
            try? FileManager.default.removeItem(at: activeBundle.bundleURL)
            try? FileManager.default.removeItem(at: developmentBundle.bundleURL)
        }

        XCTAssertEqual(
            LocalizationContext.localizedString(
                "translated",
                bundle: activeBundle,
                fallbackBundle: developmentBundle
            ),
            "Traducción"
        )
        XCTAssertEqual(
            LocalizationContext.localizedString(
                "missing_in_active",
                bundle: activeBundle,
                fallbackBundle: developmentBundle
            ),
            "English fallback"
        )
        XCTAssertEqual(
            LocalizationContext.localizedString(
                "missing_everywhere",
                bundle: activeBundle,
                fallbackBundle: developmentBundle
            ),
            "missing_everywhere"
        )
    }

    private func makeLocalizationBundle(strings: [String: String]) throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("lproj")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let contents = strings
            .sorted { $0.key < $1.key }
            .map { "\"\($0.key)\" = \"\($0.value)\";" }
            .joined(separator: "\n")
        try contents.write(
            to: bundleURL.appendingPathComponent("Localizable.strings"),
            atomically: true,
            encoding: .utf8
        )

        return try XCTUnwrap(Bundle(path: bundleURL.path))
    }
}
