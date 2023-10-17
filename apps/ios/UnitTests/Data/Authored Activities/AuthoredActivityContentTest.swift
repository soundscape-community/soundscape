//
//  AuthoredActivityContentTest.swift
//  UnitTests
//
//  Created by Kai on 10/17/23.
//  Copyright © 2023 Soundscape community. All rights reserved.
//

import XCTest
import CoreLocation
import CoreGPX
@testable import Soundscape

final class AuthoredActivityContentTest: XCTestCase {
    
    // MARK: Test GPX Parsing
    
    /// Tests parsing from GPX
    /// Using `GPXSoundscapeSharedContentExtensions` v1
    /// And minimal other details
    func testParseGPXContentV1_00() throws {
        let text = """
<gpx version="1.1">
    <metadata>
        <name>required name123</name>
        <desc>required description456</desc>
        <author>
            <name>required author's name!!</name>
            <!-- optionally other stuff here -->
        </author>

        <extensions>
            <gpxsc:meta start="date???" end="date???" expires="false">
                <!-- This is GPXSoundscapeSharedContentExtensions -->
                <gpxsc:id>activity_id1234</gpxsc:id>
                <!-- scavengerhunt is deprecated but is the only hard-coded behavior name -->
                <gpxsc:behavior>scavengerhunt</gpxsc:behavior>
                <!-- default is version 1, which uses the <wpt></wpt> tags -->
                <gpxsc:version>1</gpxsc:version>
                <gpxsc:locale>en_US</gpxsc:locale>
            </gpxsc:meta>
        </extensions>
    </metadata>

    <wpt lat="0" lon="0">
        <!-- all child properties are optional -->
        <!-- the only used ones seem to be name and desc -->
        <!-- it also can optionally use Soundscape's Links and Annotations extensions here -->
        <name>first waypoint</name>
        <desc>waypoint0</desc>
    </wpt>
    <wpt lat="1" lon="0">
        <name>second waypoint</name>
        <desc>waypoint1</desc>
    </wpt>
</gpx>
"""
        guard let parser = GPXParser(withRawString: text) else {
            XCTFail("Failed to initialize GPXParser")
            return
        }
        guard let root = parser.parsedData() else {
            XCTFail("Failed to get parsedData")
            return
        }
        guard let activity = AuthoredActivityContent.parse(gpx: root) else {
            XCTFail("Failed to create AuthoredActivityContent from GPXRoot")
            return
        }
        
        XCTAssertEqual(activity.id, "activity_id1234") // gpxsc:id
        XCTAssertEqual(activity.type, AuthoredActivityType.orienteering)
        XCTAssertEqual(activity.name, "required name123")
        XCTAssertEqual(activity.creator, "required author's name!!")
        XCTAssertEqual(activity.locale.identifier, "en_US")
        // TODO: availability???? expiration?? image??
        XCTAssertNotNil(activity.availability)
        XCTAssertFalse(activity.expires)
        
        // Note `activity.desc` and `activity.description` are different
        // desc comes from the gpxsc:desc tag, whereas description is a generated text description
        XCTAssertEqual(activity.desc, "required description456")
        
        XCTAssertEqual(activity.waypoints.count, 2)
        if let wpt0 = activity.waypoints.first, let wpt1 = activity.waypoints.last {
            XCTAssertEqual(wpt0.coordinate, CLLocationCoordinate2DMake(0, 0))
            XCTAssertEqual(wpt0.name, "first waypoint")
            XCTAssertEqual(wpt0.description, "waypoint0")
            XCTAssertEqual(wpt1.coordinate, CLLocationCoordinate2DMake(1, 0))
            XCTAssertEqual(wpt1.name, "second waypoint")
            XCTAssertEqual(wpt1.description, "waypoint1")
            // TODO: optional waypoint properties
        }

        XCTAssertEqual(activity.pois.count, 0) // v1 has no POIs
    }
    
    /// Tests parsing from GPX
    /// Using `GPXSoundscapeSharedContentExtensions` v2
    /// And minimal other details
    func testParseGPXContentV2_00() throws {
        let text = """
<gpx version="1.1">
    <metadata>
        <name>required name234</name>
        <desc>required description567</desc>
        <author>
            <name>required author's name!!</name>
            <!-- optionally other stuff here -->
        </author>

        <extensions>
            <gpxsc:meta start="date???" end="date???" expires="false">
                <!-- This is GPXSoundscapeSharedContentExtensions -->
                <gpxsc:id>activity_id5678</gpxsc:id>
                <!-- scavengerhunt is deprecated but is the only hard-coded behavior name -->
                <gpxsc:behavior>scavengerhunt</gpxsc:behavior>
                <!-- this is version 2, which uses the first route: <rte></rte> -->
                <gpxsc:version>2</gpxsc:version>
                <gpxsc:locale>en_US</gpxsc:locale>
            </gpxsc:meta>
        </extensions>
    </metadata>
    <rte>
        <!-- v2 requires all points have names -->
        <rtept lat="0" lon="0">
            <!-- same internal schema as <wpt></wpt> -->
            <!-- so same as in v1, we have optional properties and extensions -->
            <name>first point</name>
            <desc>point0</desc>
        </rtept>
        <rtept lat="1" lon="0">
            <name>second point</name>
            <desc>point1</desc>
        </rtept>
    </rte>
    <wpt lat="0.5" lon="0">
        <!-- for v2, top-level waypoints become POIs -->
        <!-- they must have a name -->
        <name>Cool POI</name>
        <desc>is optional</desc>
    </wpt>
</gpx>
"""
        guard let parser = GPXParser(withRawString: text) else {
            XCTFail("Failed to initialize GPXParser")
            return
        }
        guard let root = parser.parsedData() else {
            XCTFail("Failed to get parsedData")
            return
        }
        guard let activity = AuthoredActivityContent.parse(gpx: root) else {
            XCTFail("Failed to create AuthoredActivityContent from GPXRoot")
            return
        }
        
        XCTAssertEqual(activity.id, "activity_id5678") // gpxsc:id
        XCTAssertEqual(activity.type, AuthoredActivityType.orienteering)
        XCTAssertEqual(activity.name, "required name234")
        XCTAssertEqual(activity.creator, "required author's name!!")
        XCTAssertEqual(activity.locale.identifier, "en_US")
        // TODO: availability???? expiration?? image??
        XCTAssertNotNil(activity.availability)
        XCTAssertFalse(activity.expires)
        
        // Note `activity.desc` and `activity.description` are different
        // desc comes from the gpxsc:desc tag, whereas description is a generated text description
        XCTAssertEqual(activity.desc, "required description567")
        
        XCTAssertEqual(activity.waypoints.count, 2)
        if let wpt0 = activity.waypoints.first, let wpt1 = activity.waypoints.last {
            XCTAssertEqual(wpt0.coordinate, CLLocationCoordinate2DMake(0, 0))
            XCTAssertEqual(wpt0.name, "first point")
            XCTAssertEqual(wpt0.description, "point0")
            XCTAssertEqual(wpt1.coordinate, CLLocationCoordinate2DMake(1, 0))
            XCTAssertEqual(wpt1.name, "second point")
            XCTAssertEqual(wpt1.description, "point1")
            // TODO: optional waypoint properties
        }
        
        // POIs are the top-level waypoints
        XCTAssertEqual(activity.pois.count, 1)
        if let poi0 = activity.pois.first {
            XCTAssertEqual(poi0.coordinate, CLLocationCoordinate2DMake(0.5, 0))
            XCTAssertEqual(poi0.name, "Cool POI")
            XCTAssertEqual(poi0.description, "is optional")
        }
    }
    
    // TODO: test other stuff

}
