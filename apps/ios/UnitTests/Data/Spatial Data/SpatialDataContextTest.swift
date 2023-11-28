//
//  SpatialDataContextTest.swift
//  UnitTests
//
//  Created by Kai on 11/17/23.
//  Copyright © 2023 Soundscape community. All rights reserved.
//

import XCTest
@testable import Soundscape
import CoreLocation

final class SpatialDataContextTest: XCTestCase {

    /// This test is primarily to let us know if the reason other tests are failing is due to bugs or if it's just the connection
    func testServiceConnection() async throws {
        // need to set a location
        AppContext.shared.spatialDataContext.didUpdateLocation(CLLocation(latitude: 0, longitude: 0))
        // that way we can use it and we shouldn't get `.currentTileNil`
        let status = await AppContext.shared.spatialDataContext.checkServiceConnection()
        XCTAssertEqual(status, .success)
    }
    
    /// updateSpatialData should add the tile to our current tiles
    func testUpdateSpatialData() async throws {
        let sdc = AppContext.shared.spatialDataContext
        let rpi_loc = CLLocation(latitude: 42.73036, longitude: -73.67663)
        let rpi_tile = VectorTile(latitude: rpi_loc.coordinate.latitude, longitude: rpi_loc.coordinate.longitude, zoom: 16)
        
        // it shouldn't be loaded beforehand
        // XCTAssertTrue(sdc.currentTiles.isEmpty)
        // TODO: can we find a way to clear the persistent cache between tests?
        //XCTAssertTrue(SpatialDataCache.tileData(for: [rpi_tile]).isEmpty)
        
        _ = await sdc.updateSpatialData(at: rpi_loc)
        XCTAssertTrue(sdc.loadedSpatialData)
        XCTAssertTrue(sdc.state == .ready)
        
        // we should have the vectortile stored
        XCTAssertTrue(sdc.currentTiles.contains(where: {$0.x == rpi_tile.x && $0.y == rpi_tile.y}))
        
        // and it should now be cached
        let tiledata = SpatialDataCache.tileData(for: [rpi_tile])
        XCTAssertEqual(tiledata.count, 1)
        
    }
}
