// Copyright (c) Soundscape Community Contributers.

import Foundation
import Testing

@testable import SSDataContracts

struct UniversalLinkComponentsTests {
    @Test
    func pathComponentsUseDefaultVersionForUnversionedPaths() {
        let parsed = UniversalLinkPathComponents(path: "sharemarker")

        #expect(parsed?.path == .shareMarker)
        #expect(parsed?.version == .defaultVersion)
    }

    @Test
    func pathComponentsRoundTripKnownVersionedPath() {
        let parsed = UniversalLinkPathComponents(path: "v3/experience")

        #expect(parsed?.path == .experience)
        #expect(parsed?.version == .v3)
        #expect(parsed?.versionedPath == "/v3/experience")
    }

    @Test
    func componentsBuildExpectedShareMarkerURL() {
        let parameters = TestUniversalLinkParameters(queryItems: [
            URLQueryItem(name: "name", value: "Coffee"),
            URLQueryItem(name: "lat", value: "47.6205"),
        ])!

        let components = UniversalLinkComponents(path: .shareMarker, parameters: parameters)

        #expect(components.url?.absoluteString == "https://share.soundscape.services/v1/sharemarker?name=Coffee&lat=47.6205")
    }

    @Test
    func componentsParseURLIntoPathVersionAndQueryItems() {
        let url = URL(string: "https://share.soundscape.services/v3/experience?id=abc123")!

        let components = UniversalLinkComponents(url: url)

        #expect(components?.pathComponents.path == .experience)
        #expect(components?.pathComponents.version == .v3)
        #expect(components?.queryItems?.first?.name == "id")
        #expect(components?.queryItems?.first?.value == "abc123")
    }
}

private struct TestUniversalLinkParameters: UniversalLinkParameters {
    let queryItems: [URLQueryItem]

    init?(queryItems: [URLQueryItem]) {
        self.queryItems = queryItems
    }
}
