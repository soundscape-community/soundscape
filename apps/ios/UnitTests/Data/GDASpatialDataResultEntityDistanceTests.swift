//
//  GDASpatialDataResultEntityDistanceTests.swift
//  UnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class GDASpatialDataResultEntityDistanceTests: XCTestCase {

    func testClosestLocationFallsBackToEntityCoordinate() {
        let entity = GDASpatialDataResultEntity()
        entity.latitude = 47.6205
        entity.longitude = -122.3493

        let user = CLLocation(latitude: 47.6210, longitude: -122.3400)
        let closest = entity.closestLocation(from: user, useEntranceIfAvailable: false)
        let expectedCoordinate = CLLocationCoordinate2D(latitude: 47.6205, longitude: -122.3493)

        XCTAssertEqual(closest.coordinate.latitude, expectedCoordinate.latitude, accuracy: 1e-9)
        XCTAssertEqual(closest.coordinate.longitude, expectedCoordinate.longitude, accuracy: 1e-9)

        let expectedDistance = user.coordinate.ssGeoCoordinate.distance(to: expectedCoordinate.ssGeoCoordinate)
        XCTAssertEqual(
            entity.distanceToClosestLocation(from: user, useEntranceIfAvailable: false),
            expectedDistance,
            accuracy: 0.01
        )
    }

    func testClosestEdgeForLineStringUsesNearestVertex() {
        let entity = GDASpatialDataResultEntity()
        entity.coordinatesJson = """
        {"type":"LineString","coordinates":[[0.0,0.0],[1.0,0.0],[2.0,0.0]]}
        """

        let user = CLLocation(latitude: 0.2, longitude: 1.1)
        let expectedClosest = CLLocationCoordinate2D(latitude: 0.0, longitude: 1.0)

        guard let closest = entity.closestEdge(from: user) else {
            XCTFail("Expected a closest edge location")
            return
        }

        XCTAssertEqual(closest.coordinate.latitude, expectedClosest.latitude, accuracy: 1e-9)
        XCTAssertEqual(closest.coordinate.longitude, expectedClosest.longitude, accuracy: 1e-9)

        let expectedDistance = user.coordinate.ssGeoCoordinate.distance(to: expectedClosest.ssGeoCoordinate)
        XCTAssertEqual(
            entity.distanceToClosestLocation(from: user, useEntranceIfAvailable: false),
            expectedDistance,
            accuracy: 0.01
        )
    }

    func testBearingToClosestLocationMatchesCoordinateBearing() {
        let entity = GDASpatialDataResultEntity()
        entity.latitude = 47.6205
        entity.longitude = -122.2480
        let user = CLLocation(latitude: 47.6205, longitude: -122.3493)

        let expectedBearing = user.coordinate.bearing(to: CLLocationCoordinate2D(latitude: entity.latitude, longitude: entity.longitude))
        XCTAssertEqual(
            entity.bearingToClosestLocation(from: user, useEntranceIfAvailable: false),
            expectedBearing,
            accuracy: 0.01
        )
    }
}
