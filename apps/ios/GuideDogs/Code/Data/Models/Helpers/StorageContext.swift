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
        let markers: [Marker]
        let routes: [SavedRoute]
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

    private convenience init() {
        let preview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isolatedDirectory = preview || BuildSettings.isTesting
            ? FileManager.default.temporaryDirectory.appendingPathComponent("Soundscape-\(UUID().uuidString)")
            : nil
        self.init(isolatedDirectory: isolatedDirectory)
    }

    init(isolatedDirectory: URL?, readUserSnapshot: @escaping SnapshotReader = { try $0.snapshot() }) {
        self.isolatedDirectory = isolatedDirectory
        self.readUserSnapshot = readUserSnapshot
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

    var markers: [Marker] { snapshotLock.withLock { snapshot.markers } }
    var routes: [SavedRoute] { snapshotLock.withLock { snapshot.routes } }

    func write<T>(_ operation: (UserDataStore) throws -> T) throws -> T {
        try userQueue.sync { try writeInUserQueue(operation) }
    }

    func writeAsync<T: Sendable>(_ operation: @escaping @Sendable (UserDataStore) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            userQueue.async {
                continuation.resume(with: Result { try self.writeInUserQueue(operation) })
            }
        }
    }

    private func writeInUserQueue<T>(_ operation: (UserDataStore) throws -> T) throws -> T {
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
            try refresh(from: store)
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
