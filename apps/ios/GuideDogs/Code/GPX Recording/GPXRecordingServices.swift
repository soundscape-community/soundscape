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
        if let root {
            directory = root.appendingPathComponent("GPX Recording Draft", isDirectory: true)
        } else {
            directory = (try? InternalStorage.directory(named: "GPX Recording Draft", fileManager: fileManager))
                ?? fileManager.temporaryDirectory.appendingPathComponent("GPX Recording Draft", isDirectory: true)
        }
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

        let lines = data.split(separator: 0x0A)
        for (index, line) in lines.enumerated() {
            let entry: GPXRecordingDraftEntry
            do {
                entry = try decoder.decode(GPXRecordingDraftEntry.self, from: Data(line))
            } catch {
                let isUncommittedTrailingEntry = index == lines.indices.last && data.last != 0x0A
                guard !isUncommittedTrailingEntry else {
                    break
                }
                throw error
            }
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
    private let fileManager: FileManager
    private let localRootOverride: URL?

    init(fileManager: FileManager = .default,
         localRoot: URL? = nil) {
        self.fileManager = fileManager
        localRootOverride = localRoot
    }

    func recordings() throws -> [GPXRecordingFile] {
        try files(in: try localDirectory()).sorted {
            if $0.modifiedAt == $1.modifiedAt {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.modifiedAt > $1.modifiedAt
        }
    }

    func nameExists(_ name: String) throws -> Bool {
        let normalized = try GPXRecordingNameValidator.normalizedName(name)
        return try recordings().contains {
            $0.displayName.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    func save(gpx: String, named name: String) throws -> GPXRecordingFile {
        let normalized = try GPXRecordingNameValidator.normalizedName(name)
        guard try !nameExists(normalized) else {
            throw GPXRecordingError.duplicateName
        }

        do {
            let directory = try localDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(normalized).appendingPathExtension("gpx")
            let temporary = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("gpx")
            defer { try? fileManager.removeItem(at: temporary) }
            try Data(gpx.utf8).write(to: temporary,
                                     options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])

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
                                    modifiedAt: resourceDate(for: destination))
        } catch let error as GPXRecordingError {
            throw error
        } catch {
            throw GPXRecordingError.storage(error.localizedDescription)
        }
    }

    func prepareForSharing(_ file: GPXRecordingFile) -> URL {
        file.url
    }

    private func localDirectory() throws -> URL {
        if let localRootOverride {
            return localRootOverride.appendingPathComponent("GPX recordings", isDirectory: true)
        }
        guard let root = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return root.appendingPathComponent("GPX recordings", isDirectory: true)
    }

    private func files(in directory: URL) throws -> [GPXRecordingFile] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        return try fileManager.contentsOfDirectory(at: directory,
                                                   includingPropertiesForKeys: [.contentModificationDateKey],
                                                   options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.caseInsensitiveCompare("gpx") == .orderedSame }
            .map {
                GPXRecordingFile(url: $0,
                                 modifiedAt: resourceDate(for: $0))
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
