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

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssert(Soundscape.GeometryUtils.geometryContainsLocation(location: CLLocationCoordinate2D.init(latitude: 1, longitude: 1), coordinates: [CLLocationCoordinate2D.init(latitude: 1, longitude: 1), CLLocationCoordinate2D.init(latitude: 3, longitude: 3)]))
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
