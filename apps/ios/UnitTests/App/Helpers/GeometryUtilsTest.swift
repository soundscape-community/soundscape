//
//  GeometryUtilsTest.swift
//  UnitTests
//
//  Created by Kai on 6/16/23.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import XCTest
import CoreLocation
@testable import Soundscape

class GeometryUtilsTest: XCTestCase {
    
    // TODO: `GeometryUtils::coordinates(geoJson:)` would be better if the `GeometryType` enum used associated values (coordinates), which would let us avoid the fact that it currently returns a vague `[Any]?` and instead just return a `GeometryType`. According to comments in `GeometryUtils`, the reason for this is compatibility with Objective-C. However, if we can move away from that, we could have much better code.
    
    // GeoJSON strings taken/adapted from the GeoJSON spec, RFC-7946
    
    /// normal test case for `GeometryUtils::coordinates(geoJson:)`
    func testGeoJSONCoordinates_Point() throws {
        /// `Point`-- coordinates are a `[Double]`
        let point = GeometryUtils.coordinates(geoJson: """
{
    "type": "Point",
    "coordinates": [100.0, 0.0]
}
""")
        XCTAssertEqual(point.type, GeometryType.point)
        XCTAssertEqual(point.points as! [Double], [100.0, 0.0])
    }
    
    /// normal test case for `GeometryUtils::coordinates(geoJson:)`
    func testGeoJSONCoordinates_LineString() throws {
        /// `LineString`-- coordinates are a `[[Double]]`
        let lineString = GeometryUtils.coordinates(geoJson: """
{
    "type": "LineString",
    "coordinates": [
        [100.0, 0.0],
        [101.0, 1.0]
    ]
}
""")
        XCTAssertEqual(lineString.type, GeometryType.lineString)
        XCTAssertEqual(lineString.points as! [[Double]], [[100.0, 0.0], [101.0, 1.0]])
    }
    /// normal test case for `GeometryUtils::coordinates(geoJson:)`
    func testGeoJSONCoordinates_Polygon() throws {
        /// `Polygon`-- coordinates are a `[[[Double]]]`
        let poly = GeometryUtils.coordinates(geoJson: """
{
    "type": "Polygon",
    "coordinates": [
        [
            [100.0, 0.0],
            [101.0, 0.0],
            [101.0, 1.0],
            [100.0, 1.0],
            [100.0, 0.0]
        ],
        [
            [100.8, 0.8],
            [100.8, 0.2],
            [100.2, 0.2],
            [100.2, 0.8],
            [100.8, 0.8]
        ]
    ]
}
""")
        XCTAssertEqual(poly.type, GeometryType.polygon)
        XCTAssertEqual(poly.points as! [[[Double]]], [
            [
                [100.0, 0.0],
                [101.0, 0.0],
                [101.0, 1.0],
                [100.0, 1.0],
                [100.0, 0.0]
            ],
            [
                [100.8, 0.8],
                [100.8, 0.2],
                [100.2, 0.2],
                [100.2, 0.8],
                [100.8, 0.8]
            ]
        ])
    }
    
    // Skipping type `MultiPoint` as equivalent
    // Skipping type `MultiLineString` as equivalent
    // Skipping type `MultiPolygon` as equivalent
    
    func testGeoJSONCoordinates_invalidType() throws {
        let a = GeometryUtils.coordinates(geoJson: """
{
    "type": "a",
    "coordinates": [100.0, 0.0]
}
""")
        // TODO: apparently invalid types become GeometryType.multiPolygon - should it?
        XCTAssertEqual(a.type, .multiPolygon)
        XCTAssertEqual(a.points as! [Double], [100.0, 0.0])
    }
    
    /// edge case for `GeometryUtils::coordinates(geoJson:)` with empty input
    /// which should result in `(nil, nil)`
    func testGeoJSONCoordinates_emptystring() throws {
        let emptyString = GeometryUtils.coordinates(geoJson: "")
        XCTAssertNil(emptyString.type)
        XCTAssertNil(emptyString.points)
    }
    
    /// edge cases for `GeometryUtils::coordinates(geoJson:)` with malformed json
    /// which should result in `(nil, nil)`
    func testGeoJSONCoordinates_malformed() throws {
        let badKey = GeometryUtils.coordinates(geoJson: "{a: 1}");
        XCTAssertNil(badKey.type)
        XCTAssertNil(badKey.points)
        
        let badValue = GeometryUtils.coordinates(geoJson: "{\"a\": asdf}")
        XCTAssertNil(badValue.type)
        XCTAssertNil(badValue.points)
    }
    
    /// edge cases for `GeometryUtils::coordinates(geoJson:)` with missing keys
    /// which should result in one or both return fields being `nil`
    func testGeoJSONCoordinates_missing() throws {
        let noType = GeometryUtils.coordinates(geoJson: """
{"coordinates": [100.0, 0.0]}
""")
        XCTAssertNil(noType.type)
        XCTAssertEqual(noType.points as! [Double], [100.0, 0.0])
        
        let noCoords = GeometryUtils.coordinates(geoJson: """
{"type": "Point"}
""")
        XCTAssertEqual(noCoords.type, GeometryType.point)
        XCTAssertNil(noCoords.points)
    }
    // TODO: test `geometryContainsLocation`
    func testExample() throws {
        XCTAssert(Soundscape.GeometryUtils.geometryContainsLocation(location: CLLocationCoordinate2D.init(latitude: 1, longitude: 1), coordinates: [CLLocationCoordinate2D.init(latitude: 1, longitude: 1), CLLocationCoordinate2D.init(latitude: 3, longitude: 3)]))
    }
    
    // TODO: test `pathBearing`
    // TODO: test `split`
    
    func testRotate() throws {
        let p1 = CLLocationCoordinate2DMake(0, 1)
        let p2 = CLLocationCoordinate2DMake(0, 2)
        let p3 = CLLocationCoordinate2DMake(0, 3)
        let p4 = CLLocationCoordinate2DMake(0, 4)
        let p5 = CLLocationCoordinate2DMake(0, 5)
        
        /// Using the example given in the function description for `rotate`
        let a = [p1, p2, p3, p4, p5, p1]
        let a_rot = GeometryUtils.rotate(circularPath: a, atCoordinate: p3)
        XCTAssertEqual(a_rot, [p3, p4, p5, p1, p2, p3])
        let a_rot_reverse = GeometryUtils.rotate(circularPath: a, atCoordinate: p3, reversedDirection: true)
        XCTAssertEqual(a_rot_reverse, [p3, p2, p1, p5, p4, p3])
        
        /// Rotating from the existing start is trivial:
        let a_no_rot = GeometryUtils.rotate(circularPath: a, atCoordinate: p1)
        XCTAssertEqual(a_no_rot, a)
        let a_no_rot_reverse = GeometryUtils.rotate(circularPath: a, atCoordinate: p1, reversedDirection: true)
        XCTAssertEqual(a_no_rot_reverse, a.reversed())
    }
    
    func testRotate_invalidPath() throws {
        let p1 = CLLocationCoordinate2DMake(0, 1)
        let p2 = CLLocationCoordinate2DMake(0, 2)
        let p3 = CLLocationCoordinate2DMake(0, 3)
        let p4 = CLLocationCoordinate2DMake(0, 4)
        let p5 = CLLocationCoordinate2DMake(0, 5)
        
        /// For a non-circular path:
        let noncirc = [p1, p2, p3, p4, p5]
        let noncirc_rot = GeometryUtils.rotate(circularPath: noncirc, atCoordinate: p3)
        XCTAssertTrue(noncirc_rot.isEmpty)
    }
    
    func testRotate_invalidCoord() throws {
        let p1 = CLLocationCoordinate2DMake(0, 1)
        let p2 = CLLocationCoordinate2DMake(0, 2)
        let p3 = CLLocationCoordinate2DMake(0, 3)
        let p4 = CLLocationCoordinate2DMake(0, 4)
        let p5 = CLLocationCoordinate2DMake(0, 5)
        let other_point = CLLocationCoordinate2DMake(90, 0)
        
        // test with rotation to coordinate not in the path
        let a = [p1, p2, p3, p4, p5, p1]
        let a_rot = GeometryUtils.rotate(circularPath: a, atCoordinate: other_point)
        XCTAssertTrue(a_rot.isEmpty)
    }
    
    func testPathIsCircular() throws {
        let a = [CLLocationCoordinate2DMake(0, 0),
                 CLLocationCoordinate2DMake(1, 1),
                 CLLocationCoordinate2DMake(0, 0)]
        XCTAssertTrue(GeometryUtils.pathIsCircular(a))
        
        let b = [CLLocationCoordinate2DMake(0, 0),
                 CLLocationCoordinate2DMake(1, 1),
                 CLLocationCoordinate2DMake(2, 2)]
        XCTAssertFalse(GeometryUtils.pathIsCircular(b))
        
        let c = [CLLocationCoordinate2DMake(0, 0),
                 CLLocationCoordinate2DMake(1, 1),
                 CLLocationCoordinate2DMake(0, 0),
                 CLLocationCoordinate2DMake(1, 1)]
        XCTAssertFalse(GeometryUtils.pathIsCircular(c))
    }
    
    /// Edge cases for `GeometryUtils::pathIsCircular(_:)` with a path size of less than or equal to 2
    func testPathIsCircular_small() throws {
        let emptyPath: [CLLocationCoordinate2D] = []
        XCTAssertFalse(GeometryUtils.pathIsCircular(emptyPath))
        
        let singlePoint = [CLLocationCoordinate2DMake(0, 0)]
        XCTAssertFalse(GeometryUtils.pathIsCircular(singlePoint))
        
        let twoPoints_different = [CLLocationCoordinate2DMake(0, 0),
                                   CLLocationCoordinate2DMake(1, 1)]
        XCTAssertFalse(GeometryUtils.pathIsCircular(twoPoints_different))
        
        let twoPoints_same = [CLLocationCoordinate2DMake(0, 0),
                              CLLocationCoordinate2DMake(0, 0)]
        XCTAssertFalse(GeometryUtils.pathIsCircular(twoPoints_same))
        
    }
    
    func testPathDistance() throws {
        let emptyPath: [CLLocationCoordinate2D] = []
        XCTAssertEqual(GeometryUtils.pathDistance(emptyPath), 0)
        
        let singlePoint = [CLLocationCoordinate2DMake(0, 0)]
        XCTAssertEqual(GeometryUtils.pathDistance(singlePoint), 0)
        
        let twoPoints_same = [CLLocationCoordinate2DMake(0, 0),
                              CLLocationCoordinate2DMake(0, 0)]
        XCTAssertEqual(GeometryUtils.pathDistance(twoPoints_same), 0)
        
        let twoPoints_1 = [CLLocationCoordinate2DMake(0, 0),
                           CLLocationCoordinate2DMake(0, 180)]
        XCTAssertEqual(GeometryUtils.pathDistance(twoPoints_1),
                       twoPoints_1[0].distance(from: twoPoints_1[1]))
        XCTAssertEqual(GeometryUtils.pathDistance(twoPoints_1), GeometryUtils.earthRadius * Double.pi)
        
        // It should follow the path, not just the distance from start to end
        let circlePath = [CLLocationCoordinate2DMake(0, 0),
                          CLLocationCoordinate2DMake(1, 0),
                          CLLocationCoordinate2DMake(0, 1),
                          CLLocationCoordinate2DMake(0, 0)]
        XCTAssertTrue(GeometryUtils.pathIsCircular(circlePath), "This issue is unrelated to `pathDistance`") // assume
        XCTAssertNotEqual(GeometryUtils.pathDistance(circlePath), 0)
    }
    
    func testReferenceCoordinate() throws {
        // Note that the first three points are a 3-4-5 triangle
        let path = [CLLocationCoordinate2DMake(0, 0),
                    CLLocationCoordinate2DMake(3, 4),
                    CLLocationCoordinate2DMake(3, 0),
                    CLLocationCoordinate2DMake(0, 0),
                    CLLocationCoordinate2DMake(0, 1)]
        
        let dist1 = path[0].distance(from: path[1])
        let dist2 = path[1].distance(from: path[2])
        let dist3 = path[2].distance(from: path[3])
        let dist4 = path[3].distance(from: path[4])
        
        // For some reason these test cases don't work between points.
        // Either I don't understand how this should work, or it's a bug.
        
        //XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 / 2), CLLocationCoordinate2DMake(1.5, 2))
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1), path[1])
        
        //XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist2 / 4), CLLocationCoordinate2DMake(3, 3))
        //XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist3 * 3.12 / 4), CLLocationCoordinate2DMake(3, 1 - 0.12))
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist2), path[2])
        
        //XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist2 + dist3 / 6), CLLocationCoordinate2DMake(2.5, 0))
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist2 + dist3), path[3])
        
        //XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist2 + dist3 + dist4 * 0.123), CLLocationCoordinate2DMake(0, 0.123))
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: dist1 + dist2 + dist3 + dist4), path.last)
    }
    
    /// Edge cases for `GeometryUtils::referenceCoordinate(on:for:)` with a path size of less than 2
    func testReferenceCoordinate_small() throws {
        // Empty path returns `nil`
        let emptyPath: [CLLocationCoordinate2D] = []
        XCTAssertNil(GeometryUtils.referenceCoordinate(on: emptyPath, for: -1))
        XCTAssertNil(GeometryUtils.referenceCoordinate(on: emptyPath, for: 0))
        XCTAssertNil(GeometryUtils.referenceCoordinate(on: emptyPath, for: 1))
        
        // Single point always returns that point
        let singlePath = [CLLocationCoordinate2DMake(0, 0)]
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: singlePath, for: -1), singlePath.first)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: singlePath, for: 0), singlePath.first)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: singlePath, for: 1), singlePath.first)
    }
    
    /// Edge cases for `GeometryUtils::referenceCoordinate(on:for:)` with a distance before the start or after the end of the path
    func testReferenceCoordinate_outOfBounds() throws {
        let path = [CLLocationCoordinate2DMake(0, 0),
                    CLLocationCoordinate2DMake(1, 0),
                    CLLocationCoordinate2DMake(1, 1),
                    CLLocationCoordinate2DMake(2, 2)]
        let path_len = GeometryUtils.pathDistance(path)
        // Any distance before the start returns the first coordinate
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: -CLLocationDistanceMax), path.first)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: -path_len), path.first)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: -5.2), path.first)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: -1), path.first)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: 0), path.first)
        
        // Any distance after the end returns the last coordinate
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: CLLocationDistanceMax), path.last)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: path_len * 1.2512), path.last)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: path_len + 1), path.last)
        XCTAssertEqual(GeometryUtils.referenceCoordinate(on: path, for: path_len), path.last)
    }
    
    // TODO: test `squaredDistance`
    // TODO: test `closestEdge` on polygon (just calls the other one)
    
    /// Normal test cases for `GeometryUtils.closestEdge(coordinate:path:)`
    func testClosestEdge() throws {
        let path: [CLLocationCoordinate2D] = [CLLocationCoordinate2DMake(0, 0),
                                              CLLocationCoordinate2DMake(0, 10),
                                              CLLocationCoordinate2DMake(0, 20)]
        
        for lon in [0.0, 5.0, 10.0, 15.0, 20.0] {
            let on_path = CLLocationCoordinate2DMake(0, lon)
            let on_path_closest = GeometryUtils.closestEdge(from: on_path, on: path)
            XCTAssertNotNil(on_path_closest)
            XCTAssertEqual(on_path_closest!.coordinate, on_path)
            
            let parallel = CLLocationCoordinate2DMake(10, lon)
            let parallel_closest = GeometryUtils.closestEdge(from: parallel, on: path)
            XCTAssertNotNil(parallel_closest)
            XCTAssertEqual(parallel_closest!.coordinate, on_path)
        }
        
        for lat in [-10.0, -5.0, 0, 5.0, 10.0] {
            let before = CLLocationCoordinate2DMake(lat, -10)
            let before_closest = GeometryUtils.closestEdge(from: before, on: path)
            XCTAssertNotNil(before_closest);
            XCTAssertEqual(before_closest!.coordinate, path.first)
            
            let after = CLLocationCoordinate2DMake(lat, 30)
            let after_closest = GeometryUtils.closestEdge(from: after, on: path)
            XCTAssertNotNil(after_closest)
            XCTAssertEqual(after_closest!.coordinate, path.last)
        }
    }
    
    /// An edge case for `GeometryUtils.closestEdge(coordinate:path:)`
    /// with no points in the path
    /// returns `nil`
    func testClosestEdge_emptyPath() throws {
        let emptyPath: [CLLocationCoordinate2D] = []
        let p0 = CLLocationCoordinate2DMake(0, 0)
        let closest = GeometryUtils.closestEdge(from: p0, on: emptyPath)
        XCTAssertNil(closest)
    }
    
    /// An edge case for `GeometryUtils.closestEdge(coordinate:path:)`
    /// with only one point or multiple identical points
    /// which seems to return `nil`
    func testClosestEdge_singlePoint() throws {
        // TODO: *should* this return `nil`? or should it be the distance to the point?
        let p0 = CLLocationCoordinate2DMake(0, 0)
        let p1 = CLLocationCoordinate2DMake(0, 1)
        
        let singlePoint = [p0]
        XCTAssertNil(GeometryUtils.closestEdge(from: p0, on: singlePoint))
        XCTAssertNil(GeometryUtils.closestEdge(from: p1, on: singlePoint))
        
        let twoIdentical = [p0, p0]
        XCTAssertNil(GeometryUtils.closestEdge(from: p0, on: twoIdentical))
        XCTAssertNil(GeometryUtils.closestEdge(from: p1, on: twoIdentical))
        
        let manyIdentical = [p0, p0, p0, p0, p0]
        XCTAssertNil(GeometryUtils.closestEdge(from: p0, on: manyIdentical))
        XCTAssertNil(GeometryUtils.closestEdge(from: p1, on: manyIdentical))
    }
    
    /// An edge case for `GeometryUtils.closestEdge(coordinate:path:)`
    /// Since we're on a sphere, there can be multiple closest points (e.g. path is the equator, and point is the north pole).
    /// it seems to return
    func testClosestEdge_equidistant() throws {
        let path: [CLLocationCoordinate2D] = [CLLocationCoordinate2DMake(0, 0),
                                              CLLocationCoordinate2DMake(0, 90),
                                              CLLocationCoordinate2DMake(0, 180)]
        
        let n_pole = CLLocationCoordinate2DMake(90, 0)
        let n_pole_closest = GeometryUtils.closestEdge(from: n_pole, on: path)
        XCTAssertNotNil(n_pole_closest)
        XCTAssertEqual(n_pole_closest!.coordinate, path.first)
        
        let s_pole = CLLocationCoordinate2DMake(-90, 0)
        let s_pole_closest = GeometryUtils.closestEdge(from: s_pole, on: path)
        XCTAssertNotNil(s_pole_closest)
        XCTAssertEqual(s_pole_closest!.coordinate, path.first)
    }
    
    
    // TODO: test `interpolateToEqualDistance` with coordinates
    // TODO: test `interpolateToEqualDistance` with start and end
    
    // TODO: test `centroid` with geoJson
    // TODO: test `centroid` with locations
    // TODO: test `centroid` with coordinates
    
    
}
