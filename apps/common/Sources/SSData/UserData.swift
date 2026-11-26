// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import GRDB

public struct SavedPlace: Codable, Sendable {
    public var name: String
    public var address: String?
    public var street: String?
    public var isAddress: Bool

    public init(name: String, address: String?, street: String?, isAddress: Bool) {
        self.name = name
        self.address = address
        self.street = street
        self.isAddress = isAddress
    }
}

public struct Marker: Sendable {
    public var id: String
    public var entityKey: String?
    public var latitude: Double
    public var longitude: Double
    public var nickname: String?
    public var estimatedAddress: String?
    public var annotation: String?
    public var lastUpdatedDate: Date?
    public var lastSelectedDate: Date?
    public var isNew: Bool
    public var isTemp: Bool
    public var place: SavedPlace?

    public init(id: String = UUID().uuidString, entityKey: String? = nil,
                latitude: Double = 0, longitude: Double = 0, nickname: String? = nil,
                estimatedAddress: String? = nil, annotation: String? = nil,
                lastUpdatedDate: Date? = nil, lastSelectedDate: Date? = Date(),
                isNew: Bool = true, isTemp: Bool = true, place: SavedPlace? = nil) {
        self.id = id
        self.entityKey = entityKey
        self.latitude = latitude
        self.longitude = longitude
        self.nickname = nickname
        self.estimatedAddress = estimatedAddress
        self.annotation = annotation
        self.lastUpdatedDate = lastUpdatedDate
        self.lastSelectedDate = lastSelectedDate
        self.isNew = isNew
        self.isTemp = isTemp
        self.place = place
    }
}

public struct Waypoint: Equatable, Sendable {
    public let markerId: String
    public let index: Int

    public init(markerId: String, index: Int) {
        self.markerId = markerId
        self.index = index
    }
}

public struct SavedRoute: Sendable {
    public var id: String
    public var name: String
    public var routeDescription: String?
    public var waypoints: [Waypoint]
    public var isNew: Bool
    public var createdDate: Date
    public var lastUpdatedDate: Date
    public var lastSelectedDate: Date
    public var reversedRouteId: String?

    public init(id: String = UUID().uuidString, name: String, routeDescription: String? = nil,
                waypoints: [Waypoint], isNew: Bool = true, createdDate: Date = Date(),
                lastUpdatedDate: Date = Date(), lastSelectedDate: Date = Date(), reversedRouteId: String? = nil) {
        self.id = id
        self.name = name
        self.routeDescription = routeDescription
        self.waypoints = waypoints
        self.isNew = isNew
        self.createdDate = createdDate
        self.lastUpdatedDate = lastUpdatedDate
        self.lastSelectedDate = lastSelectedDate
        self.reversedRouteId = reversedRouteId
    }
}

public enum UserDataError: Error {
    case unsupportedSchema
    case missingMarker(String)
    case missingRoute(String)
}

public final class UserDataStore: Sendable {
    private let database: DatabaseQueue

    public init(url: URL) throws {
        let database = try DatabaseQueue(path: url.path)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("initialUserSchema") { db in
            try db.execute(sql: """
                CREATE TABLE marker (
                    id TEXT PRIMARY KEY NOT NULL, entityKey TEXT,
                    latitude REAL NOT NULL, longitude REAL NOT NULL,
                    nickname TEXT, estimatedAddress TEXT, annotation TEXT,
                    lastUpdatedDate DATETIME, lastSelectedDate DATETIME,
                    isNew INTEGER NOT NULL, isTemp INTEGER NOT NULL, place BLOB
                );
                CREATE INDEX marker_entity ON marker(entityKey);
                CREATE INDEX marker_location ON marker(latitude, longitude);
                CREATE TABLE route (
                    id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, routeDescription TEXT,
                    isNew INTEGER NOT NULL, createdDate DATETIME NOT NULL,
                    lastUpdatedDate DATETIME NOT NULL, lastSelectedDate DATETIME NOT NULL,
                    reversedRouteId TEXT REFERENCES route(id) ON DELETE SET NULL
                );
                CREATE INDEX route_name ON route(name);
                CREATE TABLE waypoint (
                    routeId TEXT NOT NULL REFERENCES route(id) ON DELETE CASCADE,
                    position INTEGER NOT NULL,
                    markerId TEXT NOT NULL REFERENCES marker(id),
                    PRIMARY KEY (routeId, position)
                );
                CREATE INDEX waypoint_marker ON waypoint(markerId);
                """)
        }
        guard try database.read({ try !migrator.hasBeenSuperseded($0) }) else {
            throw UserDataError.unsupportedSchema
        }
        try migrator.migrate(database)
        self.database = database
    }

    public static func isUnavailable(_ error: Error) -> Bool {
        guard let sqliteError = error as? DatabaseError else { return false }
        switch sqliteError.resultCode {
        case .SQLITE_CORRUPT, .SQLITE_NOTADB, .SQLITE_CANTOPEN, .SQLITE_IOERR, .SQLITE_READONLY, .SQLITE_FULL:
            return true
        default:
            return false
        }
    }

    public func markers() throws -> [Marker] {
        try database.read { db in try Row.fetchAll(db, sql: "SELECT * FROM marker ORDER BY rowid").map(Self.marker) }
    }

    public func routes() throws -> [SavedRoute] {
        try database.read { db in
            let waypoints = try Row.fetchAll(db, sql: "SELECT * FROM waypoint ORDER BY position")
            let byRoute = Dictionary(grouping: waypoints) { (row: Row) -> String in row["routeId"] }
            return try Row.fetchAll(db, sql: "SELECT * FROM route ORDER BY rowid").map { row in
                Self.route(row, waypoints: byRoute[row["id"]] ?? [])
            }
        }
    }

    public func marker(id: String) throws -> Marker? {
        try database.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM marker WHERE id = ?", arguments: [id]).map(Self.marker)
        }
    }

    public func routes(ids: [String]) throws -> [SavedRoute] {
        try database.read { db in
            try ids.compactMap { try Self.fetchRoute($0, in: db) }
        }
    }

    public func snapshot() throws -> (markers: [Marker], routes: [SavedRoute]) {
        try database.read { db in
            let markers = try Row.fetchAll(db, sql: "SELECT * FROM marker ORDER BY rowid").map(Self.marker)
            let waypoints = try Row.fetchAll(db, sql: "SELECT * FROM waypoint ORDER BY position")
            let byRoute = Dictionary(grouping: waypoints) { (row: Row) -> String in row["routeId"] }
            let routes = try Row.fetchAll(db, sql: "SELECT * FROM route ORDER BY rowid").map {
                Self.route($0, waypoints: byRoute[$0["id"]] ?? [])
            }
            return (markers, routes)
        }
    }

    public func save(marker: Marker) throws {
        try database.write { db in try Self.save(marker, in: db) }
    }

    public func save(route: SavedRoute, importing markers: [Marker] = []) throws {
        try database.write { db in
            for marker in markers { try Self.save(marker, in: db) }
            try Self.save(route, in: db)
        }
    }

    public func selectMarker(_ id: String, at date: Date) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE marker SET lastSelectedDate = ? WHERE id = ?", arguments: [date, id])
            guard db.changesCount > 0 else { throw UserDataError.missingMarker(id) }
        }
    }

    public func setMarkerTemporary(_ id: String, _ flag: Bool) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE marker SET isNew = isTemp AND NOT ?, isTemp = ? WHERE id = ?",
                           arguments: [flag, flag, id])
            guard db.changesCount > 0 else { throw UserDataError.missingMarker(id) }
        }
    }

    public func selectRoute(_ id: String, at date: Date) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE route SET lastSelectedDate = ? WHERE id = ?", arguments: [date, id])
            guard db.changesCount > 0 else { throw UserDataError.missingRoute(id) }
        }
    }

    public func clearNewMarkers() throws {
        try database.write { try $0.execute(sql: "UPDATE marker SET isNew = 0 WHERE isNew = 1") }
    }

    public func clearNewRoutes() throws {
        try database.write { try $0.execute(sql: "UPDATE route SET isNew = 0 WHERE isNew = 1") }
    }

    public func deleteRoute(_ id: String) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM route WHERE id = ?", arguments: [id])
            guard db.changesCount > 0 else { throw UserDataError.missingRoute(id) }
        }
    }

    public func deleteMarker(_ id: String) throws -> [String] {
        try database.write { db in try Self.deleteMarker(id, in: db) }
    }

    public func deleteTemporaryMarkers() throws -> [String] {
        try database.write { db in
            let ids = try String.fetchAll(db, sql: "SELECT id FROM marker WHERE isTemp = 1")
            let affected = try ids.flatMap { try Self.deleteMarker($0, in: db) }
            return Array(Set(affected)).sorted()
        }
    }

    @discardableResult
    public func erase() throws -> (markerIDs: [String], routeIDs: [String]) {
        try database.write { db in
            let markerIDs = try String.fetchAll(db, sql: "SELECT id FROM marker")
            let routeIDs = try String.fetchAll(db, sql: "SELECT id FROM route")
            try db.execute(sql: "DELETE FROM route; DELETE FROM marker")
            return (markerIDs, routeIDs)
        }
    }

    public func reverseRoute(_ id: String, suggestedName: String) throws -> (SavedRoute?, created: Bool) {
        try database.write { db in
            guard let original = try Self.fetchRoute(id, in: db) else { throw UserDataError.missingRoute(id) }
            if let linked = original.reversedRouteId, let route = try Self.fetchRoute(linked, in: db) {
                return (route, false)
            }
            guard !original.waypoints.isEmpty else { return (nil, false) }
            let reversed = original.waypoints.reversed().enumerated().map { Waypoint(markerId: $1.markerId, index: $0) }
            var name = suggestedName
            var suffix = 2
            while let existingId = try String.fetchOne(db, sql: "SELECT id FROM route WHERE name = ? ORDER BY rowid LIMIT 1", arguments: [name]),
                  let existing = try Self.fetchRoute(existingId, in: db) {
                if existing.waypoints.map(\.markerId) == reversed.map(\.markerId) { return (existing, false) }
                name = "\(suggestedName) (\(suffix))"
                suffix += 1
            }
            let route = SavedRoute(name: name, routeDescription: original.routeDescription, waypoints: reversed)
            try Self.save(route, in: db)
            try db.execute(sql: "UPDATE route SET reversedRouteId = ? WHERE id = ?", arguments: [route.id, id])
            try db.execute(sql: "UPDATE route SET reversedRouteId = ? WHERE id = ?", arguments: [id, route.id])
            return (try Self.fetchRoute(route.id, in: db), true)
        }
    }

    private static func marker(_ row: Row) throws -> Marker {
        let payload: Data? = row["place"]
        return Marker(id: row["id"], entityKey: row["entityKey"], latitude: row["latitude"],
                      longitude: row["longitude"], nickname: row["nickname"], estimatedAddress: row["estimatedAddress"],
                      annotation: row["annotation"], lastUpdatedDate: row["lastUpdatedDate"], lastSelectedDate: row["lastSelectedDate"],
                      isNew: row["isNew"], isTemp: row["isTemp"],
                      place: try payload.map { try JSONDecoder().decode(SavedPlace.self, from: $0) })
    }

    private static func route(_ row: Row, waypoints: [Row]) -> SavedRoute {
        SavedRoute(id: row["id"], name: row["name"], routeDescription: row["routeDescription"],
                   waypoints: waypoints.map { Waypoint(markerId: $0["markerId"], index: $0["position"]) },
                   isNew: row["isNew"], createdDate: row["createdDate"], lastUpdatedDate: row["lastUpdatedDate"],
                   lastSelectedDate: row["lastSelectedDate"], reversedRouteId: row["reversedRouteId"])
    }

    private static func fetchRoute(_ id: String, in db: Database) throws -> SavedRoute? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM route WHERE id = ?", arguments: [id]) else { return nil }
        let waypoints = try Row.fetchAll(db, sql: "SELECT * FROM waypoint WHERE routeId = ? ORDER BY position", arguments: [id])
        return route(row, waypoints: waypoints)
    }

    private static func save(_ marker: Marker, in db: Database) throws {
        try db.execute(sql: """
            INSERT INTO marker VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                entityKey = excluded.entityKey, latitude = excluded.latitude, longitude = excluded.longitude,
                nickname = excluded.nickname, estimatedAddress = excluded.estimatedAddress,
                annotation = excluded.annotation, lastUpdatedDate = excluded.lastUpdatedDate,
                lastSelectedDate = excluded.lastSelectedDate, isNew = excluded.isNew,
                isTemp = excluded.isTemp, place = excluded.place
            """, arguments: [marker.id, marker.entityKey, marker.latitude, marker.longitude, marker.nickname,
                             marker.estimatedAddress, marker.annotation, marker.lastUpdatedDate, marker.lastSelectedDate,
                             marker.isNew, marker.isTemp, try marker.place.map { try JSONEncoder().encode($0) }])
    }

    private static func save(_ route: SavedRoute, in db: Database) throws {
        let ordered = route.waypoints.sorted { $0.index < $1.index }
        try db.execute(sql: """
            INSERT INTO route (id, name, routeDescription, isNew, createdDate, lastUpdatedDate, lastSelectedDate)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET name = excluded.name, routeDescription = excluded.routeDescription,
                isNew = excluded.isNew, lastUpdatedDate = excluded.lastUpdatedDate, lastSelectedDate = excluded.lastSelectedDate
            """, arguments: [route.id, route.name, route.routeDescription, route.isNew,
                             route.createdDate, route.lastUpdatedDate, route.lastSelectedDate])
        try replaceWaypoints(ordered, routeId: route.id, in: db)
        try validateReverseLink(route.id, in: db)
    }

    private static func replaceWaypoints(_ waypoints: [Waypoint], routeId: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM waypoint WHERE routeId = ?", arguments: [routeId])
        for (index, waypoint) in waypoints.enumerated() {
            try db.execute(sql: "INSERT INTO waypoint VALUES (?, ?, ?)", arguments: [routeId, index, waypoint.markerId])
        }
    }

    private static func validateReverseLink(_ id: String, in db: Database) throws {
        guard let route = try fetchRoute(id, in: db), let partnerId = route.reversedRouteId,
              let partner = try fetchRoute(partnerId, in: db),
              route.waypoints.map(\.markerId) != Array(partner.waypoints.map(\.markerId).reversed()) else { return }
        try db.execute(sql: "UPDATE route SET reversedRouteId = NULL WHERE id IN (?, ?)", arguments: [id, partnerId])
    }

    private static func deleteMarker(_ id: String, in db: Database) throws -> [String] {
        let routeIds = try String.fetchAll(db, sql: "SELECT DISTINCT routeId FROM waypoint WHERE markerId = ?", arguments: [id])
        for routeId in routeIds {
            guard var route = try fetchRoute(routeId, in: db) else { continue }
            route.waypoints.removeAll { $0.markerId == id }
            let date = Date()
            try replaceWaypoints(route.waypoints, routeId: routeId, in: db)
            try db.execute(sql: "UPDATE route SET lastUpdatedDate = ?, lastSelectedDate = ? WHERE id = ?",
                           arguments: [date, date, routeId])
        }
        for routeId in routeIds { try validateReverseLink(routeId, in: db) }
        try db.execute(sql: "DELETE FROM marker WHERE id = ?", arguments: [id])
        return routeIds
    }
}
