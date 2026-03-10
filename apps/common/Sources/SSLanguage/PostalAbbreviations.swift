// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum PostalAbbreviations {
    fileprivate static func abbreviations(with locale: Locale) -> [String: String]? {
        guard
            let languageCode = locale.languageCode,
            let filePath = Bundle.module.path(forResource: "StreetSuffixAbbreviations_\(languageCode)", ofType: "plist"),
            let abbreviations = NSDictionary(contentsOfFile: filePath) as? [String: String]
        else {
            return nil
        }
        return abbreviations
    }

    public static func format(_ string: String, locale: Locale = Locale(identifier: "en")) -> String {
        guard !string.isEmpty else {
            return string
        }

        let string = expandSaintAbbreviation(string, locale: locale)
        let words = string.components(separatedBy: " ")
        return words
            .map { expandAbbreviation($0, locale: locale) }
            .joined(separator: " ")
    }

    private static func expandAbbreviation(_ string: String, locale: Locale = Locale(identifier: "en")) -> String {
        guard let expansions = abbreviations(with: locale) else {
            return string
        }

        var expansionKey = string.uppercased(with: locale).replacingOccurrences(of: ".", with: "")
        let endsWithComma = expansionKey.hasSuffix(",")

        if endsWithComma {
            expansionKey = expansionKey.replacingOccurrences(of: ",", with: "")
        }

        if let expansion = expansions[expansionKey]?.lowercased(with: locale) {
            return endsWithComma ? expansion + "," : expansion
        }

        return string
    }

    private static func expandSaintAbbreviation(_ string: String, locale: Locale) -> String {
        guard !string.isEmpty else {
            return string
        }

        let lowercased = string.lowercased(with: locale)

        if lowercased.hasPrefix("st. ") || lowercased == "st." {
            return "Saint" + string.dropFirst(3)
        }

        if lowercased.hasPrefix("st ") || lowercased == "st" {
            return "Saint" + string.dropFirst(2)
        }

        return string
    }
}
