//
//  VoiceCatalogueTests.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

final class VoiceCatalogueTests: XCTestCase {
    private let displayLocale = Locale(identifier: "en-US")

    func testProviderClassification() {
        XCTAssertNil(group(for: "com.apple.voice.standard"))
        XCTAssertEqual(group(for: "com.apple.eloquence.reed"), .eloquence)
        XCTAssertEqual(group(for: "com.apple.speech.synthesis.voice.eSpeak.en"), .eSpeak)
        XCTAssertEqual(group(for: "org.example.espeak.voice"), .eSpeak)
        XCTAssertEqual(group(for: "org.example.voice"), .other)
    }

    func testGroupsByExactLocaleIncludingDialectAndScript() {
        let catalogue = makeCatalogue(voices: [
            voice("gb", locale: "en-GB"),
            voice("us", locale: "en-US"),
            voice("traditional", locale: "zh-Hant"),
            voice("simplified", locale: "zh-Hans")
        ])

        XCTAssertEqual(
            Set(catalogue.sections.map(\.localeIdentifier)),
            Set(["en-GB", "en-US", "zh-Hant", "zh-Hans"])
        )
    }

    func testSelectedLocaleIsFirstAndReordersAfterSelection() {
        let voices = [
            voice("gb", locale: "en-GB"),
            voice("us", locale: "en-US")
        ]

        XCTAssertEqual(
            makeCatalogue(voices: voices, selected: "gb").sections.first?.localeIdentifier,
            "en-GB"
        )
        XCTAssertEqual(
            makeCatalogue(voices: voices, selected: "us").sections.first?.localeIdentifier,
            "en-US"
        )
    }

    func testMissingSelectionFallsBackToDefaultThenAppLocale() {
        let voices = [
            voice("fr", locale: "fr-FR"),
            voice("us", locale: "en-US")
        ]

        XCTAssertEqual(
            makeCatalogue(
                voices: voices,
                selected: "missing",
                defaultVoice: "fr",
                appLocale: Locale(identifier: "en-US")
            ).sections.first?.localeIdentifier,
            "fr-FR"
        )
        XCTAssertEqual(
            makeCatalogue(
                voices: voices,
                selected: "missing",
                defaultVoice: "also-missing",
                appLocale: Locale(identifier: "en-US")
            ).sections.first?.localeIdentifier,
            "en-US"
        )
    }

    func testLocalesUseLocalizedAlphabeticalOrderWithoutPriorityMatch() {
        let catalogue = makeCatalogue(
            voices: [
                voice("zulu", locale: "zu-ZA"),
                voice("french", locale: "fr-FR")
            ],
            appLocale: Locale(identifier: "en-US")
        )

        XCTAssertEqual(catalogue.sections.map(\.localeIdentifier), ["fr-FR", "zu-ZA"])
    }

    func testVoicesSortByLocalizedNameAndIdentifierTieBreak() {
        let catalogue = makeCatalogue(voices: [
            voice("com.apple.z", name: "Zoe"),
            voice("com.apple.b", name: "Alex"),
            voice("com.apple.a", name: "Alex")
        ])

        XCTAssertEqual(
            catalogue.sections[0].standardVoices.map(\.identifier),
            ["com.apple.a", "com.apple.b", "com.apple.z"]
        )
    }

    func testProviderSectionsHaveDeterministicOrderAndAggregateUnknownProviders() {
        let catalogue = makeCatalogue(voices: [
            voice("org.first.voice"),
            voice("com.apple.speech.voice.espeak.en"),
            voice("com.apple.eloquence.reed"),
            voice("net.second.voice")
        ])
        let section = catalogue.sections[0]

        XCTAssertTrue(section.standardVoices.isEmpty)
        XCTAssertEqual(section.providerSections.map(\.provider), [.eloquence, .eSpeak, .other])
        XCTAssertEqual(
            section.providerSections.last?.voices.map(\.identifier),
            ["net.second.voice", "org.first.voice"]
        )
    }

    func testSelectedProviderSummaryFindsSelectedVoice() {
        let selected = voice("org.provider.selected", name: "Selected")
        let section = makeCatalogue(voices: [
            selected,
            voice("org.provider.other", name: "Other")
        ]).sections[0].providerSections[0]

        XCTAssertEqual(
            section.selectedVoice(identifier: selected.identifier),
            selected
        )
        XCTAssertNil(section.selectedVoice(identifier: "missing"))
    }

    func testCatalogueCanContainOnlyProviderVoices() {
        let catalogue = makeCatalogue(voices: [
            voice("com.apple.eloquence.reed"),
            voice("org.provider.voice")
        ])

        XCTAssertEqual(catalogue.sections.count, 1)
        XCTAssertTrue(catalogue.sections[0].standardVoices.isEmpty)
        XCTAssertEqual(catalogue.sections[0].allVoices.count, 2)
    }

    private func group(for identifier: String) -> VoiceCatalogueProviderGroup? {
        VoiceCatalogueProviderGroup.classify(identifier: identifier)
    }

    private func voice(
        _ identifier: String,
        name: String? = nil,
        locale: String = "en-US"
    ) -> VoiceCatalogueDescriptor {
        VoiceCatalogueDescriptor(
            identifier: identifier,
            name: name ?? identifier,
            localeIdentifier: locale
        )
    }

    private func makeCatalogue(
        voices: [VoiceCatalogueDescriptor],
        selected: String? = nil,
        defaultVoice: String? = nil,
        appLocale: Locale = Locale(identifier: "de-DE")
    ) -> VoiceCatalogue {
        VoiceCatalogue(
            voices: voices,
            selectedVoiceIdentifier: selected,
            defaultVoiceIdentifier: defaultVoice,
            appLocale: appLocale,
            displayLocale: displayLocale
        )
    }
}
