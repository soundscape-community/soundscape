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

    static func directory(named name: String, fileManager: FileManager = .default) throws -> URL {
        try migrationQueue.sync {
            let destination = try applicationSupportDirectory(fileManager: fileManager)
                .appendingPathComponent(name, isDirectory: true)
            try migrateLegacyItem(named: name, to: destination, fileManager: fileManager)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            return destination
        }
    }

    static func file(named name: String, fileManager: FileManager = .default) throws -> URL {
        try migrationQueue.sync {
            let destination = try applicationSupportDirectory(fileManager: fileManager)
                .appendingPathComponent(name)
            try migrateLegacyItem(named: name, to: destination, fileManager: fileManager)
            return destination
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
                                          to destination: URL,
                                          fileManager: FileManager) throws {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let source = documents.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: source.path) else {
            return
        }
        try mergeOrMove(source: source, destination: destination, fileManager: fileManager)
    }

    private static func mergeOrMove(source: URL,
                                    destination: URL,
                                    fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: source, to: destination)
            return
        }

        let sourceIsDirectory = try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        let destinationIsDirectory = try destination.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        guard sourceIsDirectory, destinationIsDirectory else {
            try fileManager.removeItem(at: source)
            return
        }

        for child in try fileManager.contentsOfDirectory(at: source,
                                                         includingPropertiesForKeys: [.isDirectoryKey]) {
            try mergeOrMove(source: child,
                            destination: destination.appendingPathComponent(child.lastPathComponent),
                            fileManager: fileManager)
        }
        try fileManager.removeItem(at: source)
    }
}
