//
//  InternalStorageTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

final class InternalStorageTests: XCTestCase {
    private var temporaryDirectories: [URL] = []
    private var userDefaultsSuiteNames: [String] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        for suiteName in userDefaultsSuiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        userDefaultsSuiteNames.removeAll()
        try super.tearDownWithError()
    }

    func testOneTimeMigrationMovesAllLegacyItemsAndRecordsCompletion() throws {
        let root = makeTemporaryDirectory()
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let applicationSupport = root.appendingPathComponent("Application Support", isDirectory: true)
        let userDefaults = makeUserDefaults()
        try createFile(at: documents.appendingPathComponent("SharedExperiences/legacy.gpx"), contents: "route")
        try createFile(at: documents.appendingPathComponent("Experiments/controls.json"), contents: "controls")
        try createFile(at: documents.appendingPathComponent("PariedExternalDevice.json"), contents: "devices")

        try InternalStorage.migrateLegacyStorageIfNeeded(documentsDirectory: documents,
                                                         applicationSupportDirectory: applicationSupport,
                                                         fileManager: .default,
                                                         userDefaults: userDefaults)

        XCTAssertFalse(FileManager.default.fileExists(atPath: documents.appendingPathComponent("SharedExperiences").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: documents.appendingPathComponent("Experiments").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: documents.appendingPathComponent("PariedExternalDevice.json").path))
        XCTAssertEqual(try String(contentsOf: applicationSupport.appendingPathComponent("SharedExperiences/legacy.gpx")),
                       "route")
        XCTAssertEqual(try String(contentsOf: applicationSupport.appendingPathComponent("Experiments/controls.json")),
                       "controls")
        XCTAssertEqual(try String(contentsOf: applicationSupport.appendingPathComponent("PariedExternalDevice.json")),
                       "devices")
        XCTAssertEqual(userDefaults.integer(forKey: InternalStorage.migrationVersionKey),
                       InternalStorage.currentMigrationVersion)
    }

    func testOneTimeMigrationRecordsCompletionWhenThereIsNoLegacyData() throws {
        let root = makeTemporaryDirectory()
        let userDefaults = makeUserDefaults()

        try InternalStorage.migrateLegacyStorageIfNeeded(
            documentsDirectory: root.appendingPathComponent("Documents", isDirectory: true),
            applicationSupportDirectory: root.appendingPathComponent("Application Support", isDirectory: true),
            fileManager: .default,
            userDefaults: userDefaults
        )

        XCTAssertEqual(userDefaults.integer(forKey: InternalStorage.migrationVersionKey),
                       InternalStorage.currentMigrationVersion)
    }

    func testCompletedMigrationDoesNotMoveFilesCreatedLaterInDocuments() throws {
        let root = makeTemporaryDirectory()
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let applicationSupport = root.appendingPathComponent("Application Support", isDirectory: true)
        let userDefaults = makeUserDefaults()
        try InternalStorage.migrateLegacyStorageIfNeeded(documentsDirectory: documents,
                                                         applicationSupportDirectory: applicationSupport,
                                                         fileManager: .default,
                                                         userDefaults: userDefaults)
        let laterFile = documents.appendingPathComponent("SharedExperiences/later.gpx")
        try createFile(at: laterFile, contents: "later")

        try InternalStorage.migrateLegacyStorageIfNeeded(documentsDirectory: documents,
                                                         applicationSupportDirectory: applicationSupport,
                                                         fileManager: .default,
                                                         userDefaults: userDefaults)

        XCTAssertEqual(try String(contentsOf: laterFile), "later")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: applicationSupport.appendingPathComponent("SharedExperiences/later.gpx").path
        ))
    }

    func testFailureMigratesRemainingItemsAndLeavesCompletionUnsetForRetry() throws {
        let root = makeTemporaryDirectory()
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let applicationSupport = root.appendingPathComponent("Application Support", isDirectory: true)
        let userDefaults = makeUserDefaults()
        try createFile(at: documents.appendingPathComponent("SharedExperiences/legacy.gpx"), contents: "route")
        try createFile(at: documents.appendingPathComponent("Experiments/controls.json"), contents: "controls")
        try createFile(at: documents.appendingPathComponent("PariedExternalDevice.json"), contents: "devices")
        let failingFileManager = SelectiveFailingFileManager(failingItemName: "SharedExperiences")

        XCTAssertThrowsError(
            try InternalStorage.migrateLegacyStorageIfNeeded(documentsDirectory: documents,
                                                             applicationSupportDirectory: applicationSupport,
                                                             fileManager: failingFileManager,
                                                             userDefaults: userDefaults)
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: documents.appendingPathComponent("SharedExperiences").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: applicationSupport.appendingPathComponent("Experiments").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: applicationSupport.appendingPathComponent("PariedExternalDevice.json").path))
        XCTAssertEqual(userDefaults.integer(forKey: InternalStorage.migrationVersionKey), 0)

        try InternalStorage.migrateLegacyStorageIfNeeded(documentsDirectory: documents,
                                                         applicationSupportDirectory: applicationSupport,
                                                         fileManager: .default,
                                                         userDefaults: userDefaults)

        XCTAssertFalse(FileManager.default.fileExists(atPath: documents.appendingPathComponent("SharedExperiences").path))
        XCTAssertEqual(userDefaults.integer(forKey: InternalStorage.migrationVersionKey),
                       InternalStorage.currentMigrationVersion)
    }

    func testMovesLegacyItemWhenDestinationDoesNotExist() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item.json")
        let destination = root.appendingPathComponent("Application Support/item.json")
        try createFile(at: source, contents: "legacy")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination), "legacy")
    }

    func testRecursivelyMergesDirectoriesWithoutLosingChildren() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/SharedExperiences", isDirectory: true)
        let destination = root.appendingPathComponent("Application Support/SharedExperiences", isDirectory: true)
        try createFile(at: source.appendingPathComponent("legacy.json"), contents: "legacy")
        try createFile(at: source.appendingPathComponent("Nested/legacy.json"), contents: "nested legacy")
        try createFile(at: source.appendingPathComponent("Nested/shared.json"), contents: "legacy shared")
        try createFile(at: destination.appendingPathComponent("current.json"), contents: "current")
        try createFile(at: destination.appendingPathComponent("Nested/current.json"), contents: "nested current")
        try createFile(at: destination.appendingPathComponent("Nested/shared.json"), contents: "current shared")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("legacy.json")), "legacy")
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("current.json")), "current")
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("Nested/legacy.json")), "nested legacy")
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("Nested/current.json")), "nested current")
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("Nested/shared.json")), "current shared")
        XCTAssertEqual(try String(contentsOf: conflictURL(nextTo: destination.appendingPathComponent("Nested/shared.json"))),
                       "legacy shared")
    }

    func testRemovesLegacyFileOnlyWhenContentsAreIdentical() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item.json")
        let destination = root.appendingPathComponent("Application Support/item.json")
        try createFile(at: source, contents: "same")
        try createFile(at: destination, contents: "same")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination), "same")
        XCTAssertFalse(FileManager.default.fileExists(atPath: conflictURL(nextTo: destination).path))
    }

    func testPreservesDifferingLegacyFileAsMigrationConflict() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item.json")
        let destination = root.appendingPathComponent("Application Support/item.json")
        try createFile(at: source, contents: "legacy")
        try createFile(at: destination, contents: "current")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination), "current")
        XCTAssertEqual(try String(contentsOf: conflictURL(nextTo: destination)), "legacy")
    }

    func testNeverOverwritesExistingMigrationConflict() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item.json")
        let destination = root.appendingPathComponent("Application Support/item.json")
        let firstConflict = conflictURL(nextTo: destination)
        try createFile(at: source, contents: "legacy")
        try createFile(at: destination, contents: "current")
        try createFile(at: firstConflict, contents: "previous conflict")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertEqual(try String(contentsOf: destination), "current")
        XCTAssertEqual(try String(contentsOf: firstConflict), "previous conflict")
        XCTAssertEqual(try String(contentsOf: conflictURL(nextTo: destination, index: 2)), "legacy")
    }

    func testDeduplicatesAgainstIdenticalExistingMigrationConflict() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item.json")
        let destination = root.appendingPathComponent("Application Support/item.json")
        let firstConflict = conflictURL(nextTo: destination)
        try createFile(at: source, contents: "legacy")
        try createFile(at: destination, contents: "current")
        try createFile(at: firstConflict, contents: "legacy")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination), "current")
        XCTAssertEqual(try String(contentsOf: firstConflict), "legacy")
        XCTAssertFalse(FileManager.default.fileExists(atPath: conflictURL(nextTo: destination, index: 2).path))
    }

    func testPreservesDirectoryWhenDestinationIsAFile() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item", isDirectory: true)
        let destination = root.appendingPathComponent("Application Support/item")
        try createFile(at: source.appendingPathComponent("legacy.json"), contents: "legacy")
        try createFile(at: destination, contents: "current")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        let conflict = conflictURL(nextTo: destination)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: conflict.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(try String(contentsOf: conflict.appendingPathComponent("legacy.json")), "legacy")
        XCTAssertEqual(try String(contentsOf: destination), "current")
    }

    func testRetryAfterCompletedMigrationIsANoOp() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("Documents/item.json")
        let destination = root.appendingPathComponent("Application Support/item.json")
        try createFile(at: source, contents: "legacy")
        try createFile(at: destination, contents: "current")

        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)
        try InternalStorage.mergeOrMove(source: source,
                                        destination: destination,
                                        fileManager: .default)

        XCTAssertEqual(try String(contentsOf: destination), "current")
        XCTAssertEqual(try String(contentsOf: conflictURL(nextTo: destination)), "legacy")
        XCTAssertFalse(FileManager.default.fileExists(atPath: conflictURL(nextTo: destination, index: 2).path))
    }

    func testSameSourceAndDestinationIsANoOp() throws {
        let root = makeTemporaryDirectory()
        let item = root.appendingPathComponent("item.json")
        try createFile(at: item, contents: "keep")

        try InternalStorage.mergeOrMove(source: item,
                                        destination: item,
                                        fileManager: .default)

        XCTAssertEqual(try String(contentsOf: item), "keep")
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InternalStorageTests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "InternalStorageTests-\(UUID().uuidString)"
        userDefaultsSuiteNames.append(suiteName)
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func createFile(at url: URL, contents: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    private func conflictURL(nextTo destination: URL, index: Int = 1) -> URL {
        let suffix = index == 1 ? "" : ".\(index)"
        return destination.deletingLastPathComponent()
            .appendingPathComponent(destination.lastPathComponent + ".legacy-migration-conflict" + suffix)
    }
}

private final class SelectiveFailingFileManager: FileManager {
    private let failingItemName: String

    init(failingItemName: String) {
        self.failingItemName = failingItemName
        super.init()
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if srcURL.lastPathComponent == failingItemName {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
