//
//  OSMServiceModelTest.swift
//  
//
//  Created by Kai on 9/29/23.
//

import XCTest
import CoreLocation
@testable import Soundscape

final class OSMServiceModelTest: XCTestCase {
    let osm = OSMServiceModel()
    let tile0_0 = VectorTile(latitude: 0, longitude: 0, zoom: 16)
    let tileRPI = VectorTile(latitude: 42.73036, longitude: -73.67663, zoom: 16)
    
    /// Tests a point in the middle of the ocean, which should be empty
    func testGetTileData_Empty() async throws {
        let serviceResult = try await osm.getTileData(tile: tile0_0, categories: [:])
        // I think [:] means all categories
        
        guard case .modified(newEtag: let etag, tileData: let tiledata) = serviceResult else {
            XCTFail("Result was not .modified")
            return
        }
        // (0, 0) is in the Atlantic Ocean
        // There should be nothing here
        XCTAssertTrue(tiledata.pois.isEmpty)
        XCTAssertTrue(tiledata.roads.isEmpty)
        XCTAssertTrue(tiledata.paths.isEmpty)
        XCTAssertTrue(tiledata.intersections.isEmpty)
        // But we should have generated metadata
        XCTAssertFalse(tiledata.etag.isEmpty)
        XCTAssertEqual(tiledata.etag, etag)
        XCTAssertFalse(tiledata.quadkey.isEmpty)
        XCTAssertGreaterThan(tiledata.ttl.addingTimeInterval(-10), Date(timeIntervalSinceNow: 0)) // it should live past now
    }
    
    /// Tests the tile containing Rensselaer Polytechnic Institute
    func testGetTileData_RPI() async throws {
        let serviceResult = try await osm.getTileData(tile: tileRPI, categories: [:])
        // I think [:] means all categories
        
        guard case .modified(newEtag: let etag, tileData: let tiledata) = serviceResult else {
            XCTFail("Result was not .modified")
            return
        }
        
        // RPI is a busy place with lots of stuff
        // There should be a lot of data
        XCTAssertFalse(tiledata.pois.isEmpty)
        XCTAssertFalse(tiledata.roads.isEmpty)
        XCTAssertFalse(tiledata.paths.isEmpty)
        XCTAssertFalse(tiledata.intersections.isEmpty)
        // We should have generated metadata
        XCTAssertFalse(tiledata.etag.isEmpty)
        XCTAssertEqual(tiledata.etag, etag)
        XCTAssertFalse(tiledata.quadkey.isEmpty)
        XCTAssertGreaterThan(tiledata.ttl.addingTimeInterval(-10), Date(timeIntervalSinceNow: 0)) // cache should live longer than just right now
        
        // RPI should be in here
        guard let RPI = tiledata.pois.first(where: {$0.name == "Rensselaer Polytechnic Institute"}) else {
            // assuming RPI will still exist
            XCTFail("could not find RPI in its tile")
            return
        }
        XCTAssertEqual(RPI.amenity, "university")
        //XCTAssertEqual(RPI.geometryType, .multiPolygon)
        //XCTAssertEqual(RPI.dynamicURL, "https://rpi.edu")
        XCTAssertEqual(RPI.streetName, "8th Street")
        XCTAssertEqual(RPI.addressLine, "110 8th Street")
        let geometry = RPI.geometry
        XCTAssertNotNil(geometry)
        if case .multiPolygon(let coordinates) = geometry {
            XCTAssertFalse(coordinates.isEmpty)
        } else {
            XCTFail("RPI geometry should be a multiPolygon")
        }
        // Ensure RPI is roughly where it should be (with error since the exact location may shift as properties change over time)
        XCTAssertEqual(RPI.centroidLatitude, 42.73036, accuracy: 0.05)
        XCTAssertEqual(RPI.centroidLongitude, -73.67663, accuracy: 0.05)
        
        
        
        
        // get by id since there are multiple segments of Sage Avenue
        guard let sage_ave = tiledata.roads.first(where: {$0.key == "ft-282843345"}) else {
            // assuming Sage ave. will still exist
            XCTFail("could not find Sage Avenue in its tile")
            return
        }
        XCTAssertEqual(sage_ave.name, "Sage Avenue")
        XCTAssertEqual(sage_ave.type, "road")
        // XCTAssertEqual(sage_ave.geometryType, .lineString)
        XCTAssertNil(sage_ave.streetName) // Streets are at themselves, so have no address
        XCTAssertNil(sage_ave.addressLine)
        XCTAssertNil(sage_ave.phone) // Streets don't have phone numbers
        XCTAssertFalse(sage_ave.roundabout) // unless they've done work since now
        
    }

}
