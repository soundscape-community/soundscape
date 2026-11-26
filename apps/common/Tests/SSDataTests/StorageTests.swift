// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import XCTest
import SSData

final class StorageTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    func testUserDataReopensAndCacheResetDoesNotEraseIt() throws {
        let folder = try directory()
        let url = folder.appendingPathComponent("places.sqlite")
        let marker = Marker(id: "address", entityKey: "geocoded", latitude: 51, longitude: -1,
                            nickname: "Home", annotation: "Use the rear door", isTemp: false,
                            place: SavedPlace(name: "Address", address: "1 High St", street: "High St", isAddress: true))
        let route = SavedRoute(name: "Walk", waypoints: [Waypoint(markerId: marker.id, index: 0)])
        do {
            let user = try UserDataStore(url: url)
            try user.save(route: route, importing: [marker])
            try user.clearNewMarkers()
            try user.clearNewRoutes()
        }
        let tiles = try SpatialTileStore(url: folder.appendingPathComponent("tiles.sqlite"))
        try tiles.reset()
        let user = try UserDataStore(url: url)
        let snapshot = try user.snapshot()
        XCTAssertEqual(snapshot.markers.first?.nickname, "Home")
        XCTAssertEqual(snapshot.markers.first?.place?.address, "1 High St")
        XCTAssertEqual(snapshot.markers.first?.annotation, marker.annotation)
        XCTAssertEqual(snapshot.markers.first?.isNew, false)
        XCTAssertEqual(snapshot.routes.first?.isNew, false)
        XCTAssertEqual(snapshot.routes.first?.waypoints, route.waypoints)
        try user.erase()
        XCTAssertTrue(try user.markers().isEmpty)
        XCTAssertTrue(try user.routes().isEmpty)
    }

    func testImportRollsBackMarkersWhenWaypointIsMissing() throws {
        let store = try UserDataStore(url: directory().appendingPathComponent("places.sqlite"))
        let marker = Marker(id: "imported", isTemp: false)
        let route = SavedRoute(name: "Invalid", waypoints: [Waypoint(markerId: "missing", index: 0)])
        XCTAssertThrowsError(try store.save(route: route, importing: [marker]))
        XCTAssertTrue(try store.markers().isEmpty)
        XCTAssertTrue(try store.routes().isEmpty)
    }

    func testMarkerDeletionRepairsWaypointPositionAndTemporaryCleanup() throws {
        let store = try UserDataStore(url: directory().appendingPathComponent("places.sqlite"))
        let first = Marker(id: "first", isTemp: false)
        let second = Marker(id: "second", isTemp: false)
        let temporary = Marker(id: "beacon")
        let route = SavedRoute(id: "route", name: "Walk", waypoints: [
            Waypoint(markerId: temporary.id, index: 2),
            Waypoint(markerId: second.id, index: 1),
            Waypoint(markerId: first.id, index: 0)
        ])
        try store.save(route: route, importing: [first, second, temporary])
        try store.setMarkerTemporary(first.id, true)
        XCTAssertEqual(try store.deleteTemporaryMarkers(), [route.id])
        XCTAssertEqual(try store.routes().first?.waypoints, [Waypoint(markerId: second.id, index: 0)])
        XCTAssertEqual(try store.markers().map(\.id), [second.id])
    }

    func testReverseLinksSurviveMetadataEditAndUnlinkOnOrderChange() throws {
        let store = try UserDataStore(url: directory().appendingPathComponent("places.sqlite"))
        let markers = ["a", "b", "c"].map { Marker(id: $0, isTemp: false) }
        var original = SavedRoute(id: "original", name: "Walk", waypoints: markers.enumerated().map {
            Waypoint(markerId: $1.id, index: $0)
        })
        try store.save(route: original, importing: markers)
        let result = try store.reverseRoute(original.id, suggestedName: "Walk reversed")
        let reverse = try XCTUnwrap(result.0)
        XCTAssertTrue(result.created)
        XCTAssertEqual(reverse.waypoints.map(\.markerId), ["c", "b", "a"])
        XCTAssertEqual(reverse.reversedRouteId, original.id)
        original.name = "Renamed"
        try store.save(route: original)
        XCTAssertEqual(try store.routes().first { $0.id == original.id }?.reversedRouteId, reverse.id)
        XCTAssertEqual(try store.reverseRoute(original.id, suggestedName: "Another").0?.id, reverse.id)
        original.waypoints.removeLast()
        try store.save(route: original)
        XCTAssertTrue(try store.routes().allSatisfy { $0.reversedRouteId == nil })
    }

    func testDeletingSharedWaypointKeepsReversePairConsistent() throws {
        let store = try UserDataStore(url: directory().appendingPathComponent("places.sqlite"))
        let markers = ["a", "b", "c"].map { Marker(id: $0, isTemp: false) }
        let original = SavedRoute(name: "Walk", waypoints: markers.enumerated().map {
            Waypoint(markerId: $1.id, index: $0)
        })
        try store.save(route: original, importing: markers)
        let reverse = try XCTUnwrap(store.reverseRoute(original.id, suggestedName: "Walk reversed").0)
        XCTAssertEqual(Set(try store.deleteMarker("b")), [original.id, reverse.id])
        let routes = try store.routes()
        XCTAssertEqual(routes.first { $0.id == original.id }?.waypoints.map(\.markerId), ["a", "c"])
        XCTAssertEqual(routes.first { $0.id == original.id }?.reversedRouteId, reverse.id)
        XCTAssertEqual(routes.first { $0.id == reverse.id }?.waypoints.map(\.markerId), ["c", "a"])
        XCTAssertEqual(routes.first { $0.id == reverse.id }?.reversedRouteId, original.id)
    }

    func testCorruptDurableDatabaseIsPreserved() throws {
        let url = try directory().appendingPathComponent("places.sqlite")
        let original = Data("This file is not a SQLite database.".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try UserDataStore(url: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testTileReplacementEvictionAndRoadLookup() throws {
        let store = try SpatialTileStore(url: directory().appendingPathComponent("tiles.sqlite"))
        let epoch = try store.epoch()
        let expired = TileMetadata(etag: "old", expiry: Date(timeIntervalSince1970: 1))
        let left = TileFeature(key: "poi", kind: .poi, payload: Data([1]))
        let right = TileFeature(key: "poi", kind: .poi, payload: Data([2]))
        let crossing = TileFeature(key: "crossing", kind: .intersection, payload: Data([3]), roadKeys: ["way", "way"])
        let road = TileFeature(key: "way", kind: .road, payload: Data([4]))
        try store.replace(key: "01", metadata: expired, features: [left, road, crossing], epoch: epoch)
        try store.replace(key: "02", metadata: expired, features: [right, crossing], epoch: epoch)
        XCTAssertEqual(try store.feature(key: "poi", kinds: [.poi])?.payload, right.payload)
        XCTAssertEqual(try store.feature(key: "way", kinds: [.road])?.payload, road.payload)
        XCTAssertEqual(try store.intersections(roadKey: "way").map(\.key), ["crossing"])
        XCTAssertEqual(try store.tiles(keys: ["01"]).first?.2.count, 3)
        try store.evict(key: "02")
        XCTAssertEqual(try store.feature(key: "poi", kinds: [.poi])?.payload, left.payload)
        XCTAssertEqual(try store.intersections(roadKey: "way").count, 1)
        let renewed = Date(timeIntervalSince1970: 1000)
        try store.extend(key: "01", expiry: renewed, epoch: store.epoch())
        XCTAssertEqual(try store.metadata(for: "01")?.expiry, renewed)
        try store.expireAll(at: expired.expiry)
        XCTAssertEqual(try store.metadata(for: "01")?.etag, "")
        XCTAssertEqual(try store.metadata(for: "01")?.expiry, expired.expiry)
        XCTAssertNotNil(try store.feature(key: "poi", kinds: [.poi]))
    }

    func testResetRejectsStaleFetchAndCorruptCacheCanReopen() throws {
        let url = try directory().appendingPathComponent("tiles.sqlite")
        try Data("Corrupt cache".utf8).write(to: url)
        let store = try SpatialTileStore(url: url)
        let staleEpoch = try store.epoch()
        try store.reset()
        let metadata = TileMetadata(etag: "etag", expiry: Date())
        XCTAssertThrowsError(try store.replace(key: "01", metadata: metadata, features: [], epoch: staleEpoch))
        XCTAssertThrowsError(try store.extend(key: "01", expiry: Date(), epoch: store.epoch()))
        XCTAssertNil(try store.metadata(for: "01"))
    }

    func testExplicitCacheResetReclaimsDatabaseAndWALSpace() throws {
        let url = try directory().appendingPathComponent("tiles.sqlite")
        let store = try SpatialTileStore(url: url)
        let epoch = try store.epoch()
        let payload = Data(repeating: 42, count: 4 * 1024 * 1024)
        try store.replace(key: "01", metadata: TileMetadata(etag: "", expiry: Date()),
                          features: [TileFeature(key: "large", kind: .poi, payload: payload)], epoch: epoch)

        try store.reset()
        try store.reclaimDiskSpace()

        let databaseSize = try XCTUnwrap(url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let wal = URL(fileURLWithPath: url.path + "-wal")
        let walSize = (try? wal.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        XCTAssertLessThan(databaseSize + walSize, payload.count / 2)
        XCTAssertNil(try store.metadata(for: "01"))
        XCTAssertThrowsError(try store.replace(key: "01", metadata: TileMetadata(etag: "", expiry: Date()),
                                               features: [], epoch: epoch))
    }

    func testParseTileClassificationAndRelationshipsSurviveCacheEncoding() throws {
        let json = Data("""
        {
          "features": [
            {"feature_type":"tourism","feature_value":"museum","osm_ids":[10],
             "properties":{"name":"Museum","name:fr":"Musée","tourism":"museum"},
             "geometry":{"type":"Polygon","coordinates":[[[0,0],[2,0],[2,2],[0,0]]] }},
            {"feature_type":"entrance","feature_value":"main","osm_ids":[11],
             "properties":{"name":"Front entrance","entrance":"main"},
             "geometry":{"type":"Point","coordinates":[0,0]}},
            {"feature_type":"gd_entrance_list","feature_value":"","osm_ids":[10,11],
             "properties":{},"geometry":{"type":"Point","coordinates":[0,0]}},
            {"feature_type":"highway","feature_value":"residential","osm_ids":[20],
             "properties":{"name":"Main Street"},"geometry":{"type":"LineString","coordinates":[[0,0],[2,0]]}},
            {"feature_type":"highway","feature_value":"footway","osm_ids":[21],
             "properties":{"name":"Riverside path"},"geometry":{"type":"LineString","coordinates":[[0,0],[0,2]]}},
            {"feature_type":"highway","feature_value":"footway","osm_ids":[22],
             "properties":{"name":"Crossing","footway":"crossing"},"geometry":{"type":"LineString","coordinates":[[-1,0],[1,0]]}},
            {"feature_type":"highway","feature_value":"gd_intersection","osm_ids":[20,21],
             "properties":{},"geometry":{"type":"Point","coordinates":[0,0]}},
            {"feature_type":"highway","feature_value":"footway","osm_ids":[99],"properties":{"name":"Malformed"}}
          ]
        }
        """.utf8)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let now = Date(timeIntervalSince1970: 120)
        let tile = ParsedTile(json: document, quadkey: "01", etag: "test",
                              categories: [.landmarks: ["museum"]],
                              intersectionName: "Intersection", entranceListName: "Entrances", now: now)
        XCTAssertEqual(tile.metadata.expiry, now.addingTimeInterval(604_800))
        XCTAssertEqual(tile.roads.map(\.key), ["ft20"])
        XCTAssertEqual(tile.paths.map(\.key), ["ft21"])
        XCTAssertEqual(tile.pois.map(\.key), ["ft10", "ft11", "ft22"])
        XCTAssertEqual(tile.pois.map(\.superCategory), ["landmark", "entrance", "mobility"])
        XCTAssertEqual(tile.pois.first?.names.first?.string, "Musée")
        XCTAssertEqual(tile.pois.first?.entranceIDs, ["ft11"])
        XCTAssertEqual(tile.pois.last?.centroidLongitude, 0)
        XCTAssertEqual(tile.pois.last?.centroidLatitude, 0)
        XCTAssertEqual(tile.intersections.first?.key, "ft20ft210.00.0")
        XCTAssertEqual(tile.intersections.first?.roadIDs, ["ft20", "ft21"])

        let store = try SpatialTileStore(url: directory().appendingPathComponent("tiles.sqlite"))
        try store.replace(key: tile.quadkey, metadata: tile.metadata,
                          features: tile.featuresForStorage(), epoch: store.epoch())
        let cached = try XCTUnwrap(store.tiles(keys: [tile.quadkey]).first)
        let parsed = try ParsedTile(quadkey: cached.0, metadata: cached.1, features: cached.2)
        XCTAssertEqual(parsed.pois.first?.entranceIDs, ["ft11"])
        XCTAssertEqual(parsed.roads.map(\.key), tile.roads.map(\.key))
        XCTAssertEqual(try store.intersections(roadKey: "ft20").first?.mapIntersection().roadIDs, ["ft20", "ft21"])
    }

    #if os(macOS)
    func testOpeningAnOlderCacheRebuildsItWithoutChangingSavedPlaces() throws {
        let folder = try directory()
        let users = try UserDataStore(url: folder.appendingPathComponent("places.sqlite"))
        let marker = Marker(id: "saved", isTemp: false)
        try users.save(route: SavedRoute(id: "route", name: "Saved route", waypoints: [Waypoint(markerId: marker.id, index: 0)]),
                       importing: [marker])

        let url = folder.appendingPathComponent("tiles.sqlite")
        let sqlite = Process()
        sqlite.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        sqlite.arguments = [url.path, "PRAGMA user_version = 3; CREATE TABLE oldTile(payload BLOB); INSERT INTO oldTile VALUES (X'00');"]
        try sqlite.run()
        sqlite.waitUntilExit()
        XCTAssertEqual(sqlite.terminationStatus, 0)

        let rebuilt = try SpatialTileStore(url: url)
        XCTAssertEqual(try rebuilt.epoch(), 0)
        XCTAssertTrue(try rebuilt.tiles(keys: ["01"]).isEmpty)
        XCTAssertEqual(try users.markers().map(\.id), ["saved"])
        XCTAssertEqual(try users.routes().map(\.id), ["route"])
    }
    #endif

    func testMapRecentsSurviveReopenAndClearWithCache() throws {
        let url = try directory().appendingPathComponent("tiles.sqlite")
        do {
            let store = try SpatialTileStore(url: url)
            let first = TileFeature(key: "first", kind: .poi, payload: Data([1]))
            let latest = TileFeature(key: "latest", kind: .poi, payload: Data([2]))
            let now = Date(timeIntervalSince1970: 200)
            try store.replace(key: "01", metadata: TileMetadata(etag: "", expiry: now),
                              features: [first, latest], epoch: store.epoch())
            try store.recordSelection(key: "first", at: now.addingTimeInterval(-60))
            try store.recordSelection(key: "latest", at: now)
        }
        let store = try SpatialTileStore(url: url)
        XCTAssertEqual(try store.recentSelections(limit: 5).map(\.0), ["latest", "first"])
        try store.reset()
        XCTAssertTrue(try store.recentSelections(limit: 5).isEmpty)
    }

    func testConcurrentWritesHaveIndependentStoreLifetimes() async throws {
        let folder = try directory()
        let user = try UserDataStore(url: folder.appendingPathComponent("places.sqlite"))
        let tiles = try SpatialTileStore(url: folder.appendingPathComponent("tiles.sqlite"))
        let epoch = try tiles.epoch()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    let id = String(index)
                    try user.save(marker: Marker(id: id))
                    try tiles.replace(key: id, metadata: TileMetadata(etag: "", expiry: Date()),
                                      features: [], epoch: epoch)
                }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(try user.markers().count, 20)
        XCTAssertEqual(try tiles.tiles(keys: (0..<20).map(String.init)).count, 20)
    }
}
