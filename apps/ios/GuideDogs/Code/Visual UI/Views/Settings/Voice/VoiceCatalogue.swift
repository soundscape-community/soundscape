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
    let isNovelty: Bool

    init(
        identifier: String,
        name: String,
        localeIdentifier: String,
        isNovelty: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.localeIdentifier = localeIdentifier
        self.isNovelty = isNovelty
    }

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
    let noveltyVoices: [VoiceCatalogueDescriptor]
    let providerSections: [VoiceCatalogueProviderSection]

    var id: String {
        localeIdentifier
    }

    var allVoices: [VoiceCatalogueDescriptor] {
        standardVoices + noveltyVoices + providerSections.flatMap(\.voices)
    }
}

enum VoiceCatalogueCollapsedGroup: Equatable {
    case novelty
    case provider(VoiceCatalogueProviderGroup)
}

struct VoiceCatalogueExpansion: Equatable {
    let localeIdentifier: String
    let group: VoiceCatalogueCollapsedGroup
}

struct VoiceCatalogue {
    let sections: [VoiceCatalogueLanguageSection]

    init(
        voices: [VoiceCatalogueDescriptor],
        selectedVoiceIdentifier: String?,
        defaultVoiceIdentifier: String?,
        appLocale: Locale,
        displayLocale: Locale,
        preservedLocaleOrder: [String]? = nil
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

        let localeOrder = preservedLocaleOrder.map {
            Dictionary(uniqueKeysWithValues: $0.enumerated().map { ($1, $0) })
        }

        sections = groupedVoices.map { localeIdentifier, voices in
            let sortedVoices = voices.sorted {
                Self.voiceIsOrderedBefore($0, $1, locale: displayLocale)
            }
            let separatesNoveltyVoices = localeIdentifier == "en-US"
            let providerSections = VoiceCatalogueProviderGroup.allCases.compactMap { provider in
                let providerVoices = sortedVoices.filter {
                    $0.providerGroup == provider
                        && (!separatesNoveltyVoices || !$0.isNovelty)
                }
                return providerVoices.isEmpty
                    ? nil
                    : VoiceCatalogueProviderSection(provider: provider, voices: providerVoices)
            }

            return VoiceCatalogueLanguageSection(
                localeIdentifier: localeIdentifier,
                title: displayLocale.localizedString(forIdentifier: localeIdentifier)
                    ?? Locale(identifier: localeIdentifier).localizedDescription(with: displayLocale),
                standardVoices: sortedVoices.filter {
                    $0.providerGroup == nil
                        && (!separatesNoveltyVoices || !$0.isNovelty)
                },
                noveltyVoices: separatesNoveltyVoices
                    ? sortedVoices.filter(\.isNovelty)
                    : [],
                providerSections: providerSections
            )
        }
        .sorted {
            if let localeOrder {
                let lhsIndex = localeOrder[$0.localeIdentifier]
                let rhsIndex = localeOrder[$1.localeIdentifier]

                if let lhsIndex, let rhsIndex, lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }

                if lhsIndex != nil, rhsIndex == nil {
                    return true
                }

                if lhsIndex == nil, rhsIndex != nil {
                    return false
                }
            }

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
