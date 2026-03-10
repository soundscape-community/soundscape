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
}
