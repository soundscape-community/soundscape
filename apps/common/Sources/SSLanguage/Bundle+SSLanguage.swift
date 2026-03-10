// Copyright (c) Soundscape Community Contributers.

import Foundation

public extension Bundle {
    var locales: [Locale] {
        localizations
            .filter { $0 != "Base" }
            .map { Locale(identifier: $0) }
            .sorted { $0.identifier < $1.identifier }
    }

    var developmentLocale: Locale? {
        guard let developmentLocalization else {
            return nil
        }

        return Locale(identifier: developmentLocalization)
    }

    func languageBundle(for locale: Locale) -> Bundle? {
        let candidates = [
            locale.identifierHyphened.lowercased(),
            locale.identifierHyphened.replacingOccurrences(of: "-", with: "_").lowercased(),
            locale.languageCode?.lowercased(),
        ]
            .compactMap { $0 }

        for candidate in candidates {
            guard let bundlePath = path(forResource: candidate, ofType: "lproj") else {
                continue
            }

            if let bundle = Bundle(path: bundlePath) {
                return bundle
            }
        }

        return nil
    }
}
