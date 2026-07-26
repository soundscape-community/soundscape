//
//  VoiceCatalogue.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

struct VoiceCatalogueDescriptor: Equatable, Identifiable {
    let identifier: String
    let name: String
    let localeIdentifier: String

    var id: String {
        identifier
    }

    var providerGroup: VoiceCatalogueProviderGroup? {
        VoiceCatalogueProviderGroup.classify(identifier: identifier)
    }
}

enum VoiceCatalogueProviderGroup: Int, CaseIterable, Comparable, Identifiable {
    case eloquence
    case eSpeak
    case other

    var id: Self {
        self
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func classify(identifier: String) -> Self? {
        let normalizedIdentifier = identifier.lowercased()

        if normalizedIdentifier.hasPrefix("com.apple.eloquence.") {
            return .eloquence
        }

        if normalizedIdentifier.contains("espeak") {
            return .eSpeak
        }

        if !normalizedIdentifier.hasPrefix("com.apple.") {
            return .other
        }

        return nil
    }
}

struct VoiceCatalogueProviderSection: Equatable, Identifiable {
    let provider: VoiceCatalogueProviderGroup
    let voices: [VoiceCatalogueDescriptor]

    var id: VoiceCatalogueProviderGroup {
        provider
    }

    func selectedVoice(identifier: String?) -> VoiceCatalogueDescriptor? {
        voices.first { $0.identifier == identifier }
    }
}

struct VoiceCatalogueLanguageSection: Equatable, Identifiable {
    let localeIdentifier: String
    let title: String
    let standardVoices: [VoiceCatalogueDescriptor]
    let providerSections: [VoiceCatalogueProviderSection]

    var id: String {
        localeIdentifier
    }

    var allVoices: [VoiceCatalogueDescriptor] {
        standardVoices + providerSections.flatMap(\.voices)
    }
}

struct VoiceCatalogueProviderExpansion: Equatable {
    let localeIdentifier: String
    let provider: VoiceCatalogueProviderGroup
}

struct VoiceCatalogue {
    let sections: [VoiceCatalogueLanguageSection]

    init(
        voices: [VoiceCatalogueDescriptor],
        selectedVoiceIdentifier: String?,
        defaultVoiceIdentifier: String?,
        appLocale: Locale,
        displayLocale: Locale
    ) {
        let groupedVoices = Dictionary(grouping: voices) {
            Self.canonicalLocaleIdentifier($0.localeIdentifier)
        }
        let selectedLocaleIdentifier = Self.preferredLocaleIdentifier(
            voices: voices,
            selectedVoiceIdentifier: selectedVoiceIdentifier,
            defaultVoiceIdentifier: defaultVoiceIdentifier,
            appLocale: appLocale
        )

        sections = groupedVoices.map { localeIdentifier, voices in
            let sortedVoices = voices.sorted {
                Self.voiceIsOrderedBefore($0, $1, locale: displayLocale)
            }
            let providerSections = VoiceCatalogueProviderGroup.allCases.compactMap { provider in
                let providerVoices = sortedVoices.filter { $0.providerGroup == provider }
                return providerVoices.isEmpty
                    ? nil
                    : VoiceCatalogueProviderSection(provider: provider, voices: providerVoices)
            }

            return VoiceCatalogueLanguageSection(
                localeIdentifier: localeIdentifier,
                title: displayLocale.localizedString(forIdentifier: localeIdentifier)
                    ?? Locale(identifier: localeIdentifier).localizedDescription(with: displayLocale),
                standardVoices: sortedVoices.filter { $0.providerGroup == nil },
                providerSections: providerSections
            )
        }
        .sorted {
            if $0.localeIdentifier == selectedLocaleIdentifier {
                return true
            }

            if $1.localeIdentifier == selectedLocaleIdentifier {
                return false
            }

            let titleComparison = $0.title.compare(
                $1.title,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: displayLocale
            )
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return $0.localeIdentifier < $1.localeIdentifier
        }
    }

    private static func preferredLocaleIdentifier(
        voices: [VoiceCatalogueDescriptor],
        selectedVoiceIdentifier: String?,
        defaultVoiceIdentifier: String?,
        appLocale: Locale
    ) -> String? {
        if let selectedVoiceIdentifier,
           let selectedVoice = voices.first(where: { $0.identifier == selectedVoiceIdentifier }) {
            return canonicalLocaleIdentifier(selectedVoice.localeIdentifier)
        }

        if let defaultVoiceIdentifier,
           let defaultVoice = voices.first(where: { $0.identifier == defaultVoiceIdentifier }) {
            return canonicalLocaleIdentifier(defaultVoice.localeIdentifier)
        }

        let appLocaleIdentifier = canonicalLocaleIdentifier(appLocale.identifier)
        return voices.contains {
            canonicalLocaleIdentifier($0.localeIdentifier) == appLocaleIdentifier
        } ? appLocaleIdentifier : nil
    }

    private static func voiceIsOrderedBefore(
        _ lhs: VoiceCatalogueDescriptor,
        _ rhs: VoiceCatalogueDescriptor,
        locale: Locale
    ) -> Bool {
        let nameComparison = lhs.name.compare(
            rhs.name,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        )
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.identifier < rhs.identifier
    }

    private static func canonicalLocaleIdentifier(_ identifier: String) -> String {
        Locale(identifier: identifier).identifier.replacingOccurrences(of: "_", with: "-")
    }
}
