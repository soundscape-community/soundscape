// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo
import Testing

@testable import SSDataContracts

struct GDAJSONObjectAndVectorTileTests {
    @Test
    func jsonObjectNavigatesNestedValuesAndArrayIndexes() {
        let json = GDAJSONObject(string: """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "properties": {
                "name": "one"
              }
            },
            {
              "properties": {
                "name": "two",
                "count": 2
              }
            }
          ]
        }
        """)

        #expect(json?.string(atPath: "type") == "FeatureCollection")
        #expect(json?.string(atPath: "features.1.properties.name") == "two")
        #expect(json?.number(atPath: "features.1.properties.count")?.intValue == 2)
        #expect(json?.array(atPath: "features")?.count == 2)
    }

    @Test
    func jsonObjectFindsMatchingArrayElementByStringProperty() {
        let json = GDAJSONObject(string: """
        [
          { "id": "one", "value": 1 },
          { "id": "two", "value": 2 }
        ]
        """)

        let match = json?.firstArrayElement(withPropertyName: "id", equalToPropertyValue: "two")

        #expect(json?.isArray == true)
        #expect(match?.number(atPath: "value")?.intValue == 2)
        #expect(match?.jsonString.contains("\"two\"") == true)
    }

    @Test
    func vectorTileRoundTripsQuadKey() throws {
        let quadKey = try VectorTile.getQuadKey(tileX: 3, tileY: 5, zoom: 4)
        let xyz = try VectorTile.getTileXYZ(quadkey: quadKey)

        #expect(quadKey == "0213")
        #expect(xyz.x == 3)
        #expect(xyz.y == 5)
        #expect(xyz.zoom == 4)
    }

    @Test
    func vectorTileBuildsFromCoordinateAndRegionUsingSSGeo() {
        let location = SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493))
        let tile = VectorTile.tileForLocation(location, zoom: 16)
        let regionTiles = VectorTile.tilesForRegion(location, radiusMeters: 20, zoom: 16)

        #expect(tile.quadKey.isEmpty == false)
        #expect(regionTiles.isEmpty == false)
        #expect(regionTiles.contains(where: { $0 == tile }))
    }

    @Test
    func vectorTileParsesJSONPayload() {
        let payload = GDAJSONObject(string: """
        {
          "X": 10,
          "Y": 12,
          "ZoomLevel": 6,
          "QuadKey": "032210",
          "Id": "tile-id"
        }
        """)!

        let tile = VectorTile(JSON: payload)

        #expect(tile.x == 10)
        #expect(tile.y == 12)
        #expect(tile.zoom == 6)
        #expect(tile.quadKey == "032210")
        #expect(tile.id == "tile-id")
        #expect(tile.polygon.count == 5)
    }
}
