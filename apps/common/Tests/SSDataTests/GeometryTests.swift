// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

#if canImport(CoreLocation)
import CoreLocation
#else
import CoreLocationCompat
#endif
import SSData
import XCTest

final class GeometryTests: XCTestCase {
    func testTileForLocation() {
        let location = CLLocation(latitude: 51.5, longitude: -0.12)
        let tile = VectorTile.tileForLocation(location, zoom: 3)
        XCTAssertEqual(tile.x, 3)
        XCTAssertEqual(tile.y, 2)
        XCTAssertEqual(tile.zoom, 3)
        XCTAssertEqual(tile.quadKey, "031")
    }

    func testTilesForRegionAcrossEquatorAndPrimeMeridian() {
        let location = CLLocation(latitude: 0, longitude: 0)
        XCTAssertEqual(VectorTile.tilesForRegion(location, radius: 1_000, zoom: 10), [
            VectorTile(tileX: 511, tileY: 511, zoom: 10),
            VectorTile(tileX: 512, tileY: 511, zoom: 10),
            VectorTile(tileX: 511, tileY: 512, zoom: 10),
            VectorTile(tileX: 512, tileY: 512, zoom: 10)
        ])
        XCTAssertEqual(VectorTile.tilesForRegion(location, radius: 0, zoom: 10), [
            VectorTile.tileForLocation(location, zoom: 10)
        ])
    }

    func testTilePolygonCoordinates() {
        let polygon = VectorTile(tileX: 1, tileY: 1, zoom: 2).polygon
        let expected: [(latitude: Double, longitude: Double)] = [
            (66.513260443, -90), (66.513260443, 0), (0, 0), (0, -90), (66.513260443, -90)
        ]
        XCTAssertEqual(polygon.count, expected.count)
        for (coordinate, corner) in zip(polygon, expected) {
            XCTAssertEqual(coordinate.latitude, corner.latitude, accuracy: 1e-8)
            XCTAssertEqual(coordinate.longitude, corner.longitude, accuracy: 1e-8)
        }
    }

    func testGeoJSONBoundingBoxCenter() throws {
        XCTAssertNil(GeoJsonGeometry.boundingBoxCenter([]))
        let coordinates = [
            CLLocationCoordinate2D(latitude: 10, longitude: -8),
            CLLocationCoordinate2D(latitude: 12, longitude: 4),
            CLLocationCoordinate2D(latitude: 14, longitude: -5)
        ]
        let center = try XCTUnwrap(GeoJsonGeometry.boundingBoxCenter(coordinates))
        XCTAssertEqual(center.latitude, 12)
        XCTAssertEqual(center.longitude, -2)

        let geometry = try XCTUnwrap(GeoJsonGeometry(geoJSON: [
            "type": "Polygon",
            "coordinates": [[[-8.0, 10.0], [4.0, 12.0], [-5.0, 14.0], [-8.0, 10.0]]]
        ]))
        XCTAssertEqual(geometry.centroid, [-2, 12])
    }
}
