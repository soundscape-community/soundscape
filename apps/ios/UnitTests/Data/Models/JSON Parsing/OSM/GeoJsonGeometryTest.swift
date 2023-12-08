//
//  GeoJsonGeometryTest.swift
//  
//
//  Created by Kai on 11/7/23.
//

import XCTest
import CoreLocation
@testable import Soundscape

final class GeoJsonGeometryTest: XCTestCase {

    // GeoJSON strings taken/adapted from the GeoJSON spec, RFC-7946
        
    /// normal test case for `GeoJsonGeometry.init(geoJSON: String)`
    func testParseGeoJsonGeometry_Point() throws {
        /// `Point`-- coordinates are a `[Double]`
        let point = GeoJsonGeometry(geoJSON: """
{
    "type": "Point",
    "coordinates": [100.0, 0.0]
}
""")
        
        XCTAssertEqual(point, .point(coordinates: CLLocationCoordinate2DMake(0, 100)))
    }
    
    /// normal test case for `GeoJsonGeometry.init(geoJSON: String)`
    func testParseGeoJsonGeometry_LineString() throws {
        /// `LineString`-- coordinates are a `[[Double]]`
        let lineString = GeoJsonGeometry(geoJSON: """
{
    "type": "LineString",
    "coordinates": [
        [100.0, 0.0],
        [101.0, 1.0]
    ]
}
""")
        XCTAssertEqual(lineString, .lineString(coordinates: [CLLocationCoordinate2DMake(0, 100),
                                                             CLLocationCoordinate2DMake(1, 101)]))
    }
    /// normal test case for `GeoJsonGeometry.init(geoJSON: String)`
    func testParseGeoJsonGeometry_Polygon() throws {
        /// `Polygon`-- coordinates are a `[[[Double]]]`
        let poly = GeoJsonGeometry(geoJSON: """
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
        XCTAssertEqual(poly, .polygon(coordinates: [
            [
                CLLocationCoordinate2DMake(0, 100),
                CLLocationCoordinate2DMake(0, 101),
                CLLocationCoordinate2DMake(1, 101),
                CLLocationCoordinate2DMake(1, 100),
                CLLocationCoordinate2DMake(0, 100)
            ],
            [
                CLLocationCoordinate2DMake(0.8, 100.8),
                CLLocationCoordinate2DMake(0.2, 100.8),
                CLLocationCoordinate2DMake(0.2, 100.2),
                CLLocationCoordinate2DMake(0.8, 100.2),
                CLLocationCoordinate2DMake(0.8, 100.8)
            ]
        ]))
    }
    
    func testParseGeoJsonGeometry_invalidType() throws {
        let a = GeoJsonGeometry(geoJSON: """
{
    "type": "a",
    "coordinates": [100.0, 0.0]
}
""")
        XCTAssertNil(a)
    }
    
    /// edge case for `GeoJsonGeometry.init(geoJSON: String)` with empty input
    /// which should result in `(nil, nil)`
    func testParseGeoJsonGeometry_emptystring() throws {
        XCTAssertNil(GeoJsonGeometry(geoJSON: ""))
    }
    
    /// edge cases for `GeoJsonGeometry.init(geoJSON: String)` with malformed json
    func testParseGeoJsonGeometry_malformed() throws {
        XCTAssertNil(GeoJsonGeometry(geoJSON: "{a: 1}"))
        XCTAssertNil(GeoJsonGeometry(geoJSON: "{\"a\": asdf}"))
    }
    
    /// edge cases for `GeoJsonGeometry.init(geoJSON: String)` with missing keys
    /// which should result in `nil`
    func testParseGeoJsonGeometry_missing() throws {
        let noType = GeoJsonGeometry(geoJSON: """
{"coordinates": [100.0, 0.0]}
""")
        XCTAssertNil(noType)
        
        let noCoords = GeoJsonGeometry(geoJSON: """
{"type": "Point"}
""")
        XCTAssertNil(noCoords)
    }

}
