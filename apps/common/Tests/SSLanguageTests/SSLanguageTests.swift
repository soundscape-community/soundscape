// Copyright (c) Soundscape Community Contributers.

import XCTest
@testable import SSLanguage
import SSGeo

final class SSLanguageTests: XCTestCase {
    func testDistanceFormatterUsesLocaleSpecificUnits() {
        let us = DistanceFormatter(options: .init(metric: true, locale: .enUS))
        let gb = DistanceFormatter(options: .init(metric: true, locale: .enGB))

        XCTAssertEqual(us.string(fromDistance: 1), "1 meter")
        XCTAssertEqual(gb.string(fromDistance: 1), "1 metre")
    }

    func testDirectionAndCardinalLocalization() {
        XCTAssertEqual(Direction.ahead.localizedString(locale: .enUS), "ahead")
        XCTAssertEqual(CardinalDirection.southWest.localizedAbbreviatedString(locale: Locale(identifier: "sv-SE")), "SV")
    }

    func testCodeableDirectionEncodesAndDecodes() throws {
        let origin = SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493)
        let destination = SSGeoCoordinate(latitude: 47.6215, longitude: -122.3493)
        let encoded = LanguageFormatter.encodedDirection(from: origin, to: destination, heading: 0)
        let decoded = try CodeableDirection.decode(string: "Walk \(encoded)", originCoordinate: origin, originHeading: 0)

        XCTAssertEqual(decoded.direction, .ahead)
    }

    func testLocalizedLocaleDescriptionUsesModuleStrings() {
        let locale = Locale(identifier: "en-GB")
        XCTAssertEqual(locale.localizedDescription(with: Locale(identifier: "fr-FR")), "Anglais (Royaume-Uni)")
    }

    func testIntersectionPhrasesUseSharedResources() {
        XCTAssertEqual(
            LanguageFormatter.roadNameString(
                name: "Pike Street",
                direction: .left,
                roundabout: true,
                locale: .enUS
            ),
            "Pike Street, goes left in roundabout"
        )
        XCTAssertEqual(
            LanguageFormatter.approachingRoundaboutString(
                name: "Pike Street",
                includesRoundaboutInName: false,
                exitCount: 3,
                locale: .enUS
            ),
            "Approaching Pike Street roundabout with 3 exits"
        )
    }

    func testStreetAddressPhrasesUseSharedResources() {
        XCTAssertEqual(
            LanguageFormatter.namedLocationStreetAddressString(
                name: "Library",
                address: "123 Main Street",
                style: .nearby,
                locale: .enUS
            ),
            "Library is nearby. Street address is 123 Main Street."
        )
        XCTAssertEqual(
            LanguageFormatter.namedLocationStreetAddressString(
                name: "Library",
                address: "123 Main Street",
                style: .current(distance: "five meters"),
                locale: .enUS
            ),
            "Library is currently five meters. Street address is 123 Main Street."
        )
    }

    func testCardinalMovementPhrasesUseSharedResources() {
        XCTAssertEqual(
            LanguageFormatter.cardinalMovementString(
                direction: .northEast,
                style: .traveling,
                locale: .enUS
            ),
            "Traveling northeast"
        )
        XCTAssertEqual(
            LanguageFormatter.cardinalMovementString(
                direction: .west,
                style: .heading,
                roadName: "Pike Street",
                locale: .enUS
            ),
            "Heading west along Pike Street"
        )
    }
}
