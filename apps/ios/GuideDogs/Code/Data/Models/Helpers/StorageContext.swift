// Copyright (c) Microsoft Corporation.
// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import SSData

extension Notification.Name {
    static let userStorageUnavailable = Notification.Name("SoundscapeUserStorageUnavailable")
    static let userStorageRecovered = Notification.Name("SoundscapeUserStorageRecovered")
}

final class StorageContext {
    static let shared = StorageContext()

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

    private init() {
        let preview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        isolatedDirectory = preview || BuildSettings.isTesting
            ? FileManager.default.temporaryDirectory.appendingPathComponent("Soundscape-\(UUID().uuidString)")
            : nil
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
        do {
            let result = try operation(store)
            try refresh(from: store)
            return result
        } catch {
            if UserDataStore.isUnavailable(error) {
                userStore = nil
                snapshotLock.withLock { userAvailable = false }
                reportUserFailure(error)
            }
            throw error
        }
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
            guard SpatialTileStore.isRebuildable(error) else { throw error }
            let recovered = try cacheLock.withLock {
                if let cacheStore, cacheStore !== store { return cacheStore }
                try store.close()
                cacheStore = nil
                return try openSpatial()
            }
            return try read(recovered)
        }
    }

    private func openSpatial() throws -> SpatialTileStore {
        let url = try directory(.cachesDirectory, name: "Maps").appendingPathComponent("tiles.sqlite")
        let store = try SpatialTileStore(url: url)
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
            DispatchQueue.main.async { NotificationCenter.default.post(name: .userStorageRecovered, object: nil) }
        }
        return store
    }

    private func refresh(from store: UserDataStore) throws {
        let data = try store.snapshot()
        snapshotLock.withLock {
            snapshot = UserSnapshot(markers: data.markers, routes: data.routes)
        }
    }

    private func reportUserFailure(_ error: Error) {
        GDLogAppError("User database unavailable: \(error)")
        userFailure = error
        DispatchQueue.main.async { NotificationCenter.default.post(name: .userStorageUnavailable, object: nil) }
    }

    private func directory(_ location: FileManager.SearchPathDirectory, name: String) throws -> URL {
        let files = FileManager.default
        let base = try isolatedDirectory ?? files.url(for: location, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("Soundscape", isDirectory: true).appendingPathComponent(name, isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
