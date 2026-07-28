//
//  GPXRecordingServices.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import CoreGPX

actor FileGPXRecordingDraftStore: GPXRecordingDraftStore {
    private struct Metadata: Codable {
        let startedAt: Date
    }

    private let fileManager: FileManager
    private let directory: URL
    private let metadataURL: URL
    private let entriesURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, root: URL? = nil) {
        self.fileManager = fileManager
        let applicationSupport = root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = applicationSupport.appendingPathComponent("GPX Recording Draft", isDirectory: true)
        metadataURL = directory.appendingPathComponent("metadata.json")
        entriesURL = directory.appendingPathComponent("entries.jsonl")
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func create(startedAt: Date) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(Metadata(startedAt: startedAt))
            .write(to: metadataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try Data()
            .write(to: entriesURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try appendEntry(.segment)
    }

    func append(_ point: GPXRecordingPoint) throws {
        try appendEntry(.point(point))
    }

    func beginSegment() throws {
        let draft = try recover()
        guard draft?.segments.last?.isEmpty == false else {
            return
        }
        try appendEntry(.segment)
    }

    func recover() throws -> GPXRecordingDraft? {
        guard fileManager.fileExists(atPath: metadataURL.path),
              fileManager.fileExists(atPath: entriesURL.path) else {
            return nil
        }

        let metadata = try decoder.decode(Metadata.self, from: Data(contentsOf: metadataURL))
        let data = try Data(contentsOf: entriesURL)
        var segments: [[GPXRecordingPoint]] = []

        for line in data.split(separator: 0x0A) {
            let entry = try decoder.decode(GPXRecordingDraftEntry.self, from: Data(line))
            switch entry {
            case .segment:
                segments.append([])
            case .point(let point):
                if segments.isEmpty {
                    segments.append([])
                }
                segments[segments.count - 1].append(point)
            }
        }

        return GPXRecordingDraft(startedAt: metadata.startedAt, segments: segments)
    }

    func discard() throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }
        try fileManager.removeItem(at: directory)
    }

    private func appendEntry(_ entry: GPXRecordingDraftEntry) throws {
        var data = try encoder.encode(entry)
        data.append(0x0A)

        guard let handle = try? FileHandle(forWritingTo: entriesURL) else {
            throw GPXRecordingError.draftUnavailable
        }
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
}

actor FileGPXRecordingRepository: GPXRecordingRepository {
    static let iCloudContainerIdentifier = "iCloud.services.soundscape"

    private let fileManager: FileManager
    private let localRootOverride: URL?
    private let cloudRootProvider: @Sendable () -> URL?

    init(fileManager: FileManager = .default,
         localRoot: URL? = nil,
         cloudRootProvider: (@Sendable () -> URL?)? = nil) {
        self.fileManager = fileManager
        localRootOverride = localRoot
        self.cloudRootProvider = cloudRootProvider ?? {
            FileManager.default.url(forUbiquityContainerIdentifier: FileGPXRecordingRepository.iCloudContainerIdentifier)
        }
    }

    func recordings() throws -> [GPXRecordingFile] {
        let local = try files(in: localDirectory(), location: .local)
        let cloud = try cloudDirectory().map { try files(in: $0, location: .iCloud) } ?? []
        return (local + cloud).sorted {
            if $0.modifiedAt == $1.modifiedAt {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.modifiedAt > $1.modifiedAt
        }
    }

    func preferredStorageLocation() -> GPXRecordingStorageLocation {
        cloudDirectory() == nil ? .local : .iCloud
    }

    func nameExists(_ name: String) throws -> Bool {
        let normalized = try GPXRecordingNameValidator.normalizedName(name)
        return try recordings().contains {
            $0.displayName.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    func save(gpx: String, named name: String, to location: GPXRecordingStorageLocation) throws -> GPXRecordingFile {
        let normalized = try GPXRecordingNameValidator.normalizedName(name)
        guard try !nameExists(normalized) else {
            throw GPXRecordingError.duplicateName
        }

        let directory: URL
        switch location {
        case .local:
            directory = localDirectory()
        case .iCloud:
            guard let cloudDirectory = cloudDirectory() else {
                throw GPXRecordingError.iCloudSave(GDLocalizedString("gpx_recording.error.icloud_unavailable"))
            }
            directory = cloudDirectory
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(normalized).appendingPathExtension("gpx")
            let temporary = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("gpx")
            defer { try? fileManager.removeItem(at: temporary) }
            try Data(gpx.utf8).write(to: temporary, options: [.atomic, .completeFileProtection])

            var coordinationError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { coordinatedURL in
                do {
                    if self.fileManager.fileExists(atPath: coordinatedURL.path) {
                        try self.fileManager.removeItem(at: coordinatedURL)
                    }
                    try self.fileManager.moveItem(at: temporary, to: coordinatedURL)
                } catch {
                    writeError = error
                }
            }
            if let error = coordinationError ?? writeError as NSError? {
                throw error
            }

            return GPXRecordingFile(url: destination,
                                    modifiedAt: resourceDate(for: destination),
                                    storageLocation: location)
        } catch let error as GPXRecordingError {
            throw error
        } catch {
            if location == .iCloud {
                throw GPXRecordingError.iCloudSave(error.localizedDescription)
            }
            throw GPXRecordingError.storage(error.localizedDescription)
        }
    }

    func prepareForSharing(_ file: GPXRecordingFile) async throws -> URL {
        guard file.storageLocation == .iCloud else {
            return file.url
        }

        let values = try file.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if values.ubiquitousItemDownloadingStatus == .current {
            return file.url
        }

        try fileManager.startDownloadingUbiquitousItem(at: file.url)
        for _ in 0..<60 {
            try Task.checkCancellation()
            let current = try file.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if current.ubiquitousItemDownloadingStatus == .current {
                return file.url
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw GPXRecordingError.storage(GDLocalizedString("gpx_recording.error.download_timeout"))
    }

    private func localDirectory() -> URL {
        let root = localRootOverride ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("GPX recordings", isDirectory: true)
    }

    private func cloudDirectory() -> URL? {
        cloudRootProvider()?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("GPX recordings", isDirectory: true)
    }

    private func files(in directory: URL, location: GPXRecordingStorageLocation) throws -> [GPXRecordingFile] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        return try fileManager.contentsOfDirectory(at: directory,
                                                   includingPropertiesForKeys: [.contentModificationDateKey],
                                                   options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.caseInsensitiveCompare("gpx") == .orderedSame }
            .map {
                GPXRecordingFile(url: $0,
                                 modifiedAt: resourceDate(for: $0),
                                 storageLocation: location)
            }
    }

    private func resourceDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

enum GPXRecordingDocumentBuilder {
    static func makeGPX(from draft: GPXRecordingDraft) -> String {
        let segments = draft.segments
            .map { $0.map(\.gpxLocation) }
            .filter { !$0.isEmpty }
        return GPXRoot.createGPX(withTrackLocationSegments: segments).gpx()
    }
}
