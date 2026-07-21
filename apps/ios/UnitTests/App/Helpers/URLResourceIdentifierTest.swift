//
//  URLResourceIdentifierTest.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

class URLResourceIdentifierTest: XCTestCase {

    func testRecognizesSoundscapeExtension() {
        let identifier = URLResourceIdentifier(pathExtension: "soundscape")

        XCTAssertEqual(identifier, .route)
    }

    func testRecognizesSoundscapeExtensionCaseInsensitively() {
        let identifier = URLResourceIdentifier(pathExtension: "Soundscape")

        XCTAssertEqual(identifier, .route)
    }

    func testRejectsUnknownExtension() {
        let identifier = URLResourceIdentifier(pathExtension: "json")

        XCTAssertNil(identifier)
    }

    func testDoesNotRecognizeRemovedOpenscapeExtension() {
        let identifier = URLResourceIdentifier(pathExtension: "openscape")

        XCTAssertNil(identifier)
    }
}
