// Copyright (c) Microsoft Corporation.
// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import SSData

extension Notification.Name {
    static let spatialStoreInvalidated = Notification.Name("SoundscapeSpatialStoreInvalidated")
    static let userStorageUnavailable = Notification.Name("SoundscapeUserStorageUnavailable")
    static let userStorageRecovered = Notification.Name("SoundscapeUserStorageRecovered")
}

final class StorageContext {
    static let shared = StorageContext()

    typealias SnapshotReader = (UserDataStore) throws -> (markers: [Marker], routes: [SavedRoute])

    private struct UserSnapshot {
        var markerIDs: [String]
        var routeIDs: [String]
        var markers: [String: Marker]
        var routes: [String: SavedRoute]

        init(markers: [Marker], routes: [SavedRoute]) {
            markerIDs = markers.map(\.id)
            routeIDs = routes.map(\.id)
            self.markers = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
            self.routes = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })
        }

        mutating func upsert(_ marker: Marker) {
            if markers.updateValue(marker, forKey: marker.id) == nil { markerIDs.append(marker.id) }
        }

        mutating func upsert(_ route: SavedRoute) {
            if routes.updateValue(route, forKey: route.id) == nil { routeIDs.append(route.id) }
        }

        mutating func removeMarkers(_ ids: Set<String>) {
            for id in ids { markers[id] = nil }
            markerIDs.removeAll(where: ids.contains)
        }
    }

    private let userQueue = DispatchQueue(label: "org.soundscape.user-data", qos: .userInitiated)
    private let snapshotLock = NSLock()
    private var snapshot = UserSnapshot(markers: [], routes: [])
    private var userStore: UserDataStore?
    private var userAvailable = false
    private var userFailure: Error?
    private let cacheLock = NSLock()
    private var cacheStore: SpatialTileStore?
    private let isolatedDirectory: URL?
    private let readUserSnapshot: SnapshotReader
    private let readRoutes: (UserDataStore, [String]) throws -> [SavedRoute]

    private convenience init() {
        let preview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isolatedDirectory = preview || BuildSettings.isTesting
            ? FileManager.default.temporaryDirectory.appendingPathComponent("Soundscape-\(UUID().uuidString)")
            : nil
        self.init(isolatedDirectory: isolatedDirectory)
    }

    init(isolatedDirectory: URL?, readUserSnapshot: @escaping SnapshotReader = { try $0.snapshot() },
         readRoutes: @escaping (UserDataStore, [String]) throws -> [SavedRoute] = { try $0.routes(ids: $1) }) {
        self.isolatedDirectory = isolatedDirectory
        self.readUserSnapshot = readUserSnapshot
        self.readRoutes = readRoutes
    }

    func prepare(completion: @escaping () -> Void) {
        userQueue.async {
            do {
                _ = try self.openUserStore()
            } catch {
                self.reportUserFailure(error)
            }
            DispatchQueue.main.async(execute: completion)
        }
        DispatchQueue.global(qos: .utility).async {
            do {
                _ = try self.spatial()
            } catch {
                GDLogSpatialDataError("Unable to open the spatial database: \(error)")
            }
        }
    }

    var isUserStorageAvailable: Bool { snapshotLock.withLock { userAvailable } }

    var markers: [Marker] { snapshotLock.withLock { snapshot.markerIDs.compactMap { snapshot.markers[$0] } } }
    var routes: [SavedRoute] { snapshotLock.withLock { snapshot.routeIDs.compactMap { snapshot.routes[$0] } } }

    func marker(id: String) -> Marker? { snapshotLock.withLock { snapshot.markers[id] } }
    func route(id: String) -> SavedRoute? { snapshotLock.withLock { snapshot.routes[id] } }

    func saveMarker(_ marker: Marker) throws {
        try userQueue.sync {
            try commit({ try $0.save(marker: marker) }) { store, _ in
                guard let saved = try store.marker(id: marker.id) else { throw UserDataError.missingMarker(marker.id) }
                snapshotLock.withLock { snapshot.upsert(saved) }
            }
        }
    }

    func selectMarker(_ id: String, at date: Date) throws {
        try userQueue.sync {
            try commit({ try $0.selectMarker(id, at: date) }) { _, _ in
                try snapshotLock.withLock {
                    guard snapshot.markers[id] != nil else { throw UserDataError.missingMarker(id) }
                    snapshot.markers[id]?.lastSelectedDate = date
                }
            }
        }
    }

    func setMarkerTemporary(_ id: String, _ flag: Bool) throws {
        try userQueue.sync {
            try commit({ try $0.setMarkerTemporary(id, flag) }) { _, _ in
                try snapshotLock.withLock {
                    guard let wasTemporary = snapshot.markers[id]?.isTemp else { throw UserDataError.missingMarker(id) }
                    snapshot.markers[id]?.isNew = wasTemporary && !flag
                    snapshot.markers[id]?.isTemp = flag
                }
            }
        }
    }

    func selectRoute(_ id: String, at date: Date) throws {
        try userQueue.sync {
            try commit({ try $0.selectRoute(id, at: date) }) { _, _ in
                try snapshotLock.withLock {
                    guard snapshot.routes[id] != nil else { throw UserDataError.missingRoute(id) }
                    snapshot.routes[id]?.lastSelectedDate = date
                }
            }
        }
    }

    func clearNewMarkers() throws {
        try userQueue.sync {
            try commit({ try $0.clearNewMarkers() }) { _, _ in
                snapshotLock.withLock {
                    for id in snapshot.markerIDs where snapshot.markers[id]?.isNew == true {
                        snapshot.markers[id]?.isNew = false
                    }
                }
            }
        }
    }

    func clearNewRoutes() throws {
        try userQueue.sync {
            try commit({ try $0.clearNewRoutes() }) { _, _ in
                snapshotLock.withLock {
                    for id in snapshot.routeIDs where snapshot.routes[id]?.isNew == true {
                        snapshot.routes[id]?.isNew = false
                    }
                }
            }
        }
    }

    func saveRoute(_ route: SavedRoute, importing markers: [Marker]) throws {
        try userQueue.sync { try saveRouteOnUserQueue(route, importing: markers) }
    }

    func saveRouteAsync(_ route: SavedRoute, importing markers: [Marker]) async throws {
        try await onUserQueue { try self.saveRouteOnUserQueue(route, importing: markers) }
    }

    private func saveRouteOnUserQueue(_ route: SavedRoute, importing markers: [Marker]) throws {
        try commit({ try $0.save(route: route, importing: markers) }) { store, _ in
            let savedRoutes = try refreshedRoutes([route.id], from: store)
            let savedMarkers = try markers.map { marker in
                guard let saved = try store.marker(id: marker.id) else { throw UserDataError.missingMarker(marker.id) }
                return saved
            }
            snapshotLock.withLock {
                for marker in savedMarkers { snapshot.upsert(marker) }
                for route in savedRoutes { snapshot.upsert(route) }
            }
        }
    }

    func deleteRoute(_ id: String) throws {
        try userQueue.sync {
            try commit({ try $0.deleteRoute(id) }) { store, _ in
                let linked = route(id: id)?.reversedRouteId
                let updated = try linked.map { try readRoutes(store, [$0]) } ?? []
                snapshotLock.withLock {
                    snapshot.routes[id] = nil
                    snapshot.routeIDs.removeAll { $0 == id }
                    for route in updated { snapshot.upsert(route) }
                }
            }
        }
    }

    func reverseRoute(_ id: String, suggestedName: String) throws -> (SavedRoute?, created: Bool) {
        try userQueue.sync {
            try commit({ try $0.reverseRoute(id, suggestedName: suggestedName) }) { store, result in
                guard result.created, let reversed = result.0 else { return }
                let updated = try readRoutes(store, [id])
                snapshotLock.withLock {
                    snapshot.upsert(reversed)
                    for route in updated { snapshot.upsert(route) }
                }
            }
        }
    }

    func deleteMarker(_ id: String) throws -> [String] {
        try userQueue.sync {
            try commit({ try $0.deleteMarker(id) }) { store, ids in
                try applyMarkerDeletion([id], routes: ids, from: store)
            }
        }
    }

    func deleteTemporaryMarkers() throws -> [String] {
        try userQueue.sync {
            try commit({ try $0.deleteTemporaryMarkers() }) { store, ids in
                let temporary = snapshotLock.withLock { Set(snapshot.markers.values.filter(\.isTemp).map(\.id)) }
                try applyMarkerDeletion(temporary, routes: ids, from: store)
            }
        }
    }

    private func applyMarkerDeletion(_ markers: Set<String>, routes: [String], from store: UserDataStore) throws {
        let updated = try refreshedRoutes(routes, from: store)
        snapshotLock.withLock {
            snapshot.removeMarkers(markers)
            for route in updated { snapshot.upsert(route) }
        }
    }

    private func refreshedRoutes(_ ids: [String], from store: UserDataStore) throws -> [SavedRoute] {
        let partners = snapshotLock.withLock { ids.compactMap { snapshot.routes[$0]?.reversedRouteId } }
        let affected = Set(ids + partners)
        return affected.isEmpty ? [] : try readRoutes(store, affected.sorted())
    }

    func eraseUserData() async throws -> (markerIDs: [String], routeIDs: [String]) {
        try await onUserQueue {
            try self.commit({ try $0.erase() }) { _, _ in
                self.snapshotLock.withLock { self.snapshot = UserSnapshot(markers: [], routes: []) }
            }
        }
    }

    private func onUserQueue<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            userQueue.async { continuation.resume(with: Result(catching: operation)) }
        }
    }

    private func commit<T>(_ operation: (UserDataStore) throws -> T,
                           apply: (UserDataStore, T) throws -> Void) throws -> T {
        let store: UserDataStore
        do {
            store = try openUserStore()
        } catch {
            reportUserFailure(error)
            throw error
        }
        let result: T
        do {
            result = try operation(store)
        } catch {
            if UserDataStore.isUnavailable(error) { invalidateUserStore(error) }
            throw error
        }
        do {
            try apply(store, result)
        } catch {
            GDLogAppError("User database write committed, but refreshing saved places failed: \(error)")
            invalidateUserStore(error)
        }
        return result
    }

    private func invalidateUserStore(_ error: Error) {
        userStore = nil
        snapshotLock.withLock { userAvailable = false }
        reportUserFailure(error)
    }

    func spatial() throws -> SpatialTileStore {
        try cacheLock.withLock {
            if let cacheStore { return cacheStore }
            return try openSpatial()
        }
    }

    func withSpatialStore<T>(_ read: (SpatialTileStore) throws -> T) throws -> T {
        let store = try spatial()
        do {
            return try read(store)
        } catch {
            return try read(recoverSpatialStore(store, after: error))
        }
    }

    func isCurrentSpatialStore(_ store: SpatialTileStore) -> Bool {
        cacheLock.withLock { cacheStore === store }
    }

    func recoverSpatialStore(_ store: SpatialTileStore, after error: Error) throws -> SpatialTileStore {
        guard SpatialTileStore.isRebuildable(error) else { throw error }
        return try cacheLock.withLock {
            if cacheStore !== store {
                if let cacheStore { return cacheStore }
                return try openSpatial()
            }
            try store.close()
            cacheStore = nil
            defer {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .spatialStoreInvalidated, object: self)
                }
            }
            let rebuilt = try SpatialTileStore.rebuild(at: spatialURL())
            cacheStore = rebuilt
            return rebuilt
        }
    }

    private func spatialURL() throws -> URL {
        try directory(.cachesDirectory, name: "Maps").appendingPathComponent("tiles.sqlite")
    }

    private func openSpatial() throws -> SpatialTileStore {
        let store = try SpatialTileStore(url: spatialURL())
        cacheStore = store
        return store
    }

    private func openUserStore() throws -> UserDataStore {
        if let userStore { return userStore }
        let url = try directory(.applicationSupportDirectory, name: "UserData").appendingPathComponent("places.sqlite")
        let store = try UserDataStore(url: url)
        try refresh(from: store)
        userStore = store
        snapshotLock.withLock { userAvailable = true }
        if userFailure != nil {
            userFailure = nil
            DispatchQueue.main.async { NotificationCenter.default.post(name: .userStorageRecovered, object: self) }
        }
        return store
    }

    private func refresh(from store: UserDataStore) throws {
        let data = try readUserSnapshot(store)
        snapshotLock.withLock {
            snapshot = UserSnapshot(markers: data.markers, routes: data.routes)
        }
    }

    private func reportUserFailure(_ error: Error) {
        GDLogAppError("User database unavailable: \(error)")
        userFailure = error
        DispatchQueue.main.async { NotificationCenter.default.post(name: .userStorageUnavailable, object: self) }
    }

    private func directory(_ location: FileManager.SearchPathDirectory, name: String) throws -> URL {
        let files = FileManager.default
        let base = try isolatedDirectory ?? files.url(for: location, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("Soundscape", isDirectory: true).appendingPathComponent(name, isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
