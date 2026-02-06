//
//  IntersectionDistanceTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class IntersectionDistanceTests: XCTestCase {

    func testFindClosestReturnsNilForEmptyInput() {
        let origin = CLLocation(latitude: 47.6205, longitude: -122.3493)
        XCTAssertNil(Intersection.findClosest(intersections: [], location: origin))
    }

    func testFindClosestReturnsNearestIntersection() {
        let origin = CLLocation(latitude: 47.6205, longitude: -122.3493)

        let nearest = Intersection()
        nearest.latitude = 47.6206
        nearest.longitude = -122.3494

        let farther = Intersection()
        farther.latitude = 47.6220
        farther.longitude = -122.3400

        let result = Intersection.findClosest(intersections: [farther, nearest], location: origin)
        XCTAssertTrue(result === nearest)
    }
}
