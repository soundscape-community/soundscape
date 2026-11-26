// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import GRDB

public struct TileMetadata: Sendable {
    public let etag: String
    public let expiry: Date

    public init(etag: String, expiry: Date) {
        self.etag = etag
        self.expiry = expiry
    }
}

public struct TileFeature: Sendable {
    public enum Kind: Int, Sendable {
        case poi, road, path, intersection
    }

    public let key: String
    public let kind: Kind
    public let payload: Data
    fileprivate let roadKeys: [String]

    public init(key: String, kind: Kind, payload: Data, roadKeys: [String] = []) {
        self.key = key
        self.kind = kind
        self.payload = payload
        self.roadKeys = roadKeys
    }
}

public enum SpatialStorageError: Error {
    case invalidatedFetch
    case missingTile
    case incompatibleSchema
}

public final class SpatialTileStore: Sendable {
    private let database: DatabasePool
    private static let schemaVersion = 3

    public init(url: URL) throws {
        do {
            database = try Self.open(url)
        } catch {
            guard Self.isRebuildable(error) else { throw error }
            for suffix in ["", "-wal", "-shm"] {
                let file = URL(fileURLWithPath: url.path + suffix)
                do {
                    try FileManager.default.removeItem(at: file)
                } catch let error as CocoaError where error.code == .fileNoSuchFile {
                    continue
                }
            }
            database = try Self.open(url)
        }
    }

    public static func isRebuildable(_ error: Error) -> Bool {
        if case SpatialStorageError.incompatibleSchema = error { return true }
        guard let error = error as? DatabaseError else { return false }
        return error.resultCode == .SQLITE_CORRUPT || error.resultCode == .SQLITE_NOTADB
    }

    private static func open(_ url: URL) throws -> DatabasePool {
        let pool = try DatabasePool(path: url.path)
        let version = try pool.read { try Int.fetchOne($0, sql: "PRAGMA user_version") ?? 0 }
        guard version == 0 || version == schemaVersion else { throw SpatialStorageError.incompatibleSchema }
        if version == 0 {
            try pool.write { db in
                try db.execute(sql: """
                    CREATE TABLE tile (
                        quadkey TEXT PRIMARY KEY NOT NULL, etag TEXT NOT NULL,
                        expiry DATETIME NOT NULL, revision INTEGER NOT NULL
                    );
                    CREATE TABLE feature (
                        quadkey TEXT NOT NULL REFERENCES tile(quadkey) ON DELETE CASCADE,
                        position INTEGER NOT NULL, key TEXT NOT NULL, kind INTEGER NOT NULL,
                        payload BLOB NOT NULL,
                        PRIMARY KEY (quadkey, position)
                    );
                    CREATE INDEX feature_key ON feature(key, kind);
                    CREATE TABLE intersectionRoad (
                        roadKey TEXT NOT NULL, quadkey TEXT NOT NULL, position INTEGER NOT NULL,
                        PRIMARY KEY (roadKey, quadkey, position),
                        FOREIGN KEY (quadkey, position) REFERENCES feature(quadkey, position) ON DELETE CASCADE
                    );
                    CREATE INDEX intersection_feature ON intersectionRoad(quadkey, position);
                    CREATE TABLE recentSelection (key TEXT PRIMARY KEY NOT NULL, selectedAt DATETIME NOT NULL);
                    CREATE TABLE cacheState (epoch INTEGER NOT NULL, revision INTEGER NOT NULL);
                    INSERT INTO cacheState VALUES (0, 0);
                    PRAGMA user_version = \(schemaVersion);
                    """)
            }
        }
        return pool
    }

    public func metadata(for key: String) throws -> TileMetadata? {
        try database.read { db in
            try Row.fetchOne(db, sql: "SELECT etag, expiry FROM tile WHERE quadkey = ?", arguments: [key])
                .map { TileMetadata(etag: $0["etag"], expiry: $0["expiry"]) }
        }
    }

    public func epoch() throws -> Int {
        try database.read { try Self.epoch(in: $0) }
    }

    public func replace(key: String, metadata: TileMetadata, features: [TileFeature], epoch: Int) throws {
        try database.write { db in
            guard try Self.epoch(in: db) == epoch else { throw SpatialStorageError.invalidatedFetch }
            try db.execute(sql: "UPDATE cacheState SET revision = revision + 1")
            try db.execute(sql: "DELETE FROM tile WHERE quadkey = ?", arguments: [key])
            try db.execute(sql: "INSERT INTO tile SELECT ?, ?, ?, revision FROM cacheState",
                           arguments: [key, metadata.etag, metadata.expiry])
            let insertFeature = try db.cachedStatement(sql: "INSERT INTO feature VALUES (?, ?, ?, ?, ?)")
            let insertRoad = try db.cachedStatement(sql: "INSERT INTO intersectionRoad VALUES (?, ?, ?)")
            for (position, feature) in features.enumerated() {
                try insertFeature.execute(arguments: [key, position, feature.key, feature.kind.rawValue, feature.payload])
                for road in Set(feature.roadKeys) {
                    try insertRoad.execute(arguments: [road, key, position])
                }
            }
        }
    }

    public func extend(key: String, expiry: Date, epoch: Int) throws {
        try database.write { db in
            guard try Self.epoch(in: db) == epoch else { throw SpatialStorageError.invalidatedFetch }
            try db.execute(sql: "UPDATE tile SET expiry = ? WHERE quadkey = ?", arguments: [expiry, key])
            guard db.changesCount > 0 else { throw SpatialStorageError.missingTile }
        }
    }

    public func expireAll(at date: Date) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE cacheState SET epoch = epoch + 1")
            try db.execute(sql: "UPDATE tile SET expiry = ?, etag = ''", arguments: [date])
        }
    }

    public func evict(key: String) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE cacheState SET epoch = epoch + 1")
            try db.execute(sql: "DELETE FROM tile WHERE quadkey = ?", arguments: [key])
        }
    }

    public func reset() throws {
        try database.write { db in
            try db.execute(sql: "UPDATE cacheState SET epoch = epoch + 1")
            try db.execute(sql: "DELETE FROM tile; DELETE FROM recentSelection")
        }
    }

    public func close() throws {
        try database.close()
    }

    public func recordSelection(key: String, at date: Date) throws {
        try database.write { db in
            try db.execute(sql: """
                INSERT INTO recentSelection VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET selectedAt = MAX(recentSelection.selectedAt, excluded.selectedAt)
                """, arguments: [key, date])
        }
    }

    public func recentSelections(limit: Int) throws -> [(String, Date)] {
        try database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT selection.key, selection.selectedAt FROM recentSelection AS selection
                WHERE EXISTS (SELECT 1 FROM feature WHERE key = selection.key AND kind <> ?)
                ORDER BY selection.selectedAt DESC, selection.key LIMIT ?
                """, arguments: [TileFeature.Kind.intersection.rawValue, limit]).map { ($0["key"], $0["selectedAt"]) }
        }
    }

    public func tiles(keys: [String]) throws -> [(String, TileMetadata, [TileFeature])] {
        try database.read { db in
            try keys.compactMap { key in
                guard let tile = try Row.fetchOne(db, sql: "SELECT etag, expiry FROM tile WHERE quadkey = ?", arguments: [key]) else { return nil }
                let features = try Row.fetchAll(db, sql: "SELECT key, kind, payload FROM feature WHERE quadkey = ? ORDER BY position", arguments: [key])
                return (key, TileMetadata(etag: tile["etag"], expiry: tile["expiry"]), features.compactMap(Self.feature))
            }
        }
    }

    public func feature(key: String, kinds: [TileFeature.Kind]) throws -> TileFeature? {
        guard !kinds.isEmpty else { return nil }
        let placeholders = Array(repeating: "?", count: kinds.count).joined(separator: ", ")
        let arguments = StatementArguments([key]) + StatementArguments(kinds.map(\.rawValue))
        return try database.read { db in
            try Row.fetchOne(db, sql: """
                SELECT feature.key, feature.kind, feature.payload FROM feature JOIN tile USING (quadkey)
                WHERE feature.key = ? AND feature.kind IN (\(placeholders))
                ORDER BY tile.revision DESC, feature.quadkey, feature.position LIMIT 1
                """, arguments: arguments).flatMap(Self.feature)
        }
    }

    public func intersections(roadKey: String) throws -> [TileFeature] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT feature.key, feature.kind, feature.payload
                FROM intersectionRoad JOIN feature USING (quadkey, position) JOIN tile USING (quadkey)
                WHERE intersectionRoad.roadKey = ?
                ORDER BY tile.revision DESC, feature.quadkey, feature.position
                """, arguments: [roadKey])
            var keys: Set<String> = []
            return rows.compactMap(Self.feature).filter { keys.insert($0.key).inserted }
        }
    }

    private static func epoch(in db: Database) throws -> Int {
        guard let epoch = try Int.fetchOne(db, sql: "SELECT epoch FROM cacheState") else {
            throw SpatialStorageError.incompatibleSchema
        }
        return epoch
    }

    private static func feature(_ row: Row) -> TileFeature? {
        guard let kind = TileFeature.Kind(rawValue: row["kind"]) else { return nil }
        return TileFeature(key: row["key"], kind: kind, payload: row["payload"])
    }
}
