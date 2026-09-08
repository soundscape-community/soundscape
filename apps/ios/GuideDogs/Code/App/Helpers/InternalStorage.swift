//
//  InternalStorage.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

enum InternalStorage {
    private static let migrationQueue = DispatchQueue(label: "services.soundscape.internal-storage-migration")
    private static let migrationConflictSuffix = ".legacy-migration-conflict"
    static let migrationVersionKey = "GDAInternalStorageMigrationVersion"
    static let currentMigrationVersion = 1
    private static let legacyItemNames = [
        "SharedExperiences",
        "Experiments",
        "PariedExternalDevice.json"
    ]

    static func directory(named name: String, fileManager: FileManager = .default) throws -> URL {
        let destination = try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        return destination
    }

    static func file(named name: String, fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(name)
    }

    static func migrateLegacyStorageIfNeeded(fileManager: FileManager = .default,
                                             userDefaults: UserDefaults = .standard) throws {
        guard userDefaults.integer(forKey: migrationVersionKey) < currentMigrationVersion else {
            return
        }
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let applicationSupport = try applicationSupportDirectory(fileManager: fileManager)
        try migrateLegacyStorageIfNeeded(documentsDirectory: documents,
                                         applicationSupportDirectory: applicationSupport,
                                         fileManager: fileManager,
                                         userDefaults: userDefaults)
    }

    static func migrateLegacyStorageIfNeeded(documentsDirectory: URL,
                                             applicationSupportDirectory: URL,
                                             fileManager: FileManager,
                                             userDefaults: UserDefaults) throws {
        try migrationQueue.sync {
            guard userDefaults.integer(forKey: migrationVersionKey) < currentMigrationVersion else {
                return
            }

            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

            var firstError: Error?
            for name in legacyItemNames {
                do {
                    try migrateLegacyItem(named: name,
                                          from: documentsDirectory,
                                          to: applicationSupportDirectory,
                                          fileManager: fileManager)
                } catch {
                    if firstError == nil {
                        firstError = error
                    }
                }
            }

            if let firstError {
                throw firstError
            }
            userDefaults.set(currentMigrationVersion, forKey: migrationVersionKey)
        }
    }

    private static func applicationSupportDirectory(fileManager: FileManager) throws -> URL {
        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func migrateLegacyItem(named name: String,
                                          from documentsDirectory: URL,
                                          to applicationSupportDirectory: URL,
                                          fileManager: FileManager) throws {
        let source = documentsDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: source.path) else {
            return
        }
        let destination = applicationSupportDirectory.appendingPathComponent(name)
        try mergeOrMove(source: source, destination: destination, fileManager: fileManager)
    }

    static func mergeOrMove(source: URL,
                            destination: URL,
                            fileManager: FileManager) throws {
        guard source.standardizedFileURL != destination.standardizedFileURL else {
            return
        }
        guard fileManager.fileExists(atPath: source.path) else {
            return
        }

        var coordinationError: NSError?
        var migrationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: source,
                                       options: .forMoving,
                                       writingItemAt: destination,
                                       options: .forMerging,
                                       error: &coordinationError) { coordinatedSource, coordinatedDestination in
            do {
                try mergeOrMoveCoordinated(source: coordinatedSource,
                                           destination: coordinatedDestination,
                                           fileManager: fileManager)
            } catch {
                migrationError = error
            }
        }
        if let error = coordinationError ?? migrationError as NSError? {
            throw error
        }
    }

    private static func mergeOrMoveCoordinated(source: URL,
                                               destination: URL,
                                               fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            return
        }
        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: source, to: destination)
            return
        }

        let sourceIsDirectory = try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        let destinationIsDirectory = try destination.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        if sourceIsDirectory, destinationIsDirectory {
            for child in try fileManager.contentsOfDirectory(at: source,
                                                             includingPropertiesForKeys: [.isDirectoryKey]) {
                try mergeOrMoveCoordinated(source: child,
                                           destination: destination.appendingPathComponent(child.lastPathComponent),
                                           fileManager: fileManager)
            }
            try fileManager.removeItem(at: source)
            return
        }

        if fileManager.contentsEqual(atPath: source.path, andPath: destination.path) {
            try fileManager.removeItem(at: source)
            return
        }

        // The destination may already contain newer state. Keep it authoritative while
        // moving the legacy item aside so a migration never destroys either version.
        try preserveMigrationConflict(source: source,
                                      nextTo: destination,
                                      fileManager: fileManager)
    }

    private static func preserveMigrationConflict(source: URL,
                                                  nextTo destination: URL,
                                                  fileManager: FileManager) throws {
        let baseName = destination.lastPathComponent + migrationConflictSuffix
        var index = 1

        while true {
            let name = index == 1 ? baseName : "\(baseName).\(index)"
            let conflict = destination.deletingLastPathComponent().appendingPathComponent(name)
            guard fileManager.fileExists(atPath: conflict.path) else {
                try fileManager.moveItem(at: source, to: conflict)
                return
            }
            if fileManager.contentsEqual(atPath: source.path, andPath: conflict.path) {
                try fileManager.removeItem(at: source)
                return
            }
            index += 1
        }
    }
}
