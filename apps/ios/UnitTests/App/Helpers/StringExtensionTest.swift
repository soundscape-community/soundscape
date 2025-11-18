//
//  StringExtensionTest.swift
//  UnitTests
//
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import XCTest
@testable import Soundscape

final class StringExtensionTest: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testAccessibilityStringPreservesCapitalization() throws {
        // Test that capitalization is preserved
        let input = "Soundscape is a great app"
        let result = input.accessibilityString()
        XCTAssertEqual(result, "Soundscape is a great app", "Capitalization should be preserved")
    }
    
    func testAccessibilityStringPreservesSentenceCase() throws {
        // Test that sentence case is preserved
        let input = "This is a sentence. This is another sentence."
        let result = input.accessibilityString()
        XCTAssertEqual(result, "This is a sentence. This is another sentence.", "Sentence case should be preserved")
    }
    
    func testAccessibilityStringReplacesCallout() throws {
        // Test that "callout" is replaced with "call out"
        let input = "Use the callout feature"
        let result = input.accessibilityString()
        XCTAssertEqual(result, "Use the call out feature", "'callout' should be replaced with 'call out'")
    }
    
    func testAccessibilityStringReplacesCalloutCaseInsensitive() throws {
        // Test that "Callout" (capitalized) is replaced with "call out"
        let input = "Shake to Repeat the Last Callout"
        let result = input.accessibilityString()
        XCTAssertEqual(result, "Shake to Repeat the Last call out", "'Callout' should be replaced with 'call out' (case-insensitive)")
    }
    
    func testAccessibilityStringReplacesCalloutMixedCase() throws {
        // Test that "CALLOUT" (uppercase) is replaced with "call out"
        let input = "The CALLOUT system"
        let result = input.accessibilityString()
        XCTAssertEqual(result, "The call out system", "'CALLOUT' should be replaced with 'call out'")
    }
    
    func testAccessibilityStringNoCallout() throws {
        // Test strings without "callout"
        let input = "Beacon Mute Distance Setting"
        let result = input.accessibilityString()
        XCTAssertEqual(result, "Beacon Mute Distance Setting", "Strings without 'callout' should remain unchanged")
    }
    
    func testAccessibilityStringEmptyString() throws {
        // Test empty string
        let input = ""
        let result = input.accessibilityString()
        XCTAssertEqual(result, "", "Empty string should remain empty")
    }
    
    func testAccessibilityStringMultipleCallouts() throws {
        // Test multiple callouts in the same string
        let input = "The callout feature allows you to make a callout"
        let result = input.accessibilityString()
        XCTAssertEqual(result, "The call out feature allows you to make a call out", "Multiple 'callout' instances should all be replaced")
    }
}
