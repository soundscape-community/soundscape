//
//  GPXRecordingModels.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

struct GPXRecordingFile: Identifiable, Equatable, Sendable {
    let url: URL
    let modifiedAt: Date

    var id: String {
        url.standardizedFileURL.path
    }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }
}

struct GPXRecordingPoint: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double
    let timestamp: Date
    let heading: Double?
    let motionActivity: String?

    init(location: CLLocation, heading: Double?, motionActivity: String?) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        elevation = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        speed = location.speed
        course = location.course
        timestamp = location.timestamp
        self.heading = heading
        self.motionActivity = motionActivity
    }

    var gpxLocation: GPXLocation {
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                  altitude: elevation,
                                  horizontalAccuracy: horizontalAccuracy,
                                  verticalAccuracy: verticalAccuracy,
                                  course: course,
                                  speed: speed,
                                  timestamp: timestamp)
        return GPXLocation(location: location, deviceHeading: heading, activity: motionActivity)
    }
}

enum GPXRecordingDraftEntry: Codable, Equatable, Sendable {
    case segment
    case point(GPXRecordingPoint)

    private enum CodingKeys: String, CodingKey {
        case type
        case point
    }

    private enum EntryType: String, Codable {
        case segment
        case point
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(EntryType.self, forKey: .type) {
        case .segment:
            self = .segment
        case .point:
            self = .point(try container.decode(GPXRecordingPoint.self, forKey: .point))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .segment:
            try container.encode(EntryType.segment, forKey: .type)
        case .point(let point):
            try container.encode(EntryType.point, forKey: .type)
            try container.encode(point, forKey: .point)
        }
    }
}

struct GPXRecordingDraft: Equatable, Sendable {
    let startedAt: Date
    let segments: [[GPXRecordingPoint]]

    var pointCount: Int {
        segments.reduce(0) { $0 + $1.count }
    }
}

enum GPXRecordingState: Equatable, Sendable {
    case loading
    case idle
    case starting
    case recording
    case paused
    case awaitingName
    case saving
    case recoverableInterruption
}

enum GPXRecordingError: LocalizedError, Equatable {
    case noPoints
    case invalidName
    case duplicateName
    case draftUnavailable
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .noPoints:
            return GDLocalizedString("gpx_recording.error.no_points")
        case .invalidName:
            return GDLocalizedString("gpx_recording.error.invalid_name")
        case .duplicateName:
            return GDLocalizedString("gpx_recording.error.duplicate_name")
        case .draftUnavailable:
            return GDLocalizedString("gpx_recording.error.draft_unavailable")
        case .storage(let description):
            return description
        }
    }
}

enum GPXRecordingNameValidator {
    static func normalizedName(_ proposedName: String) throws -> String {
        var name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased().hasSuffix(".gpx") {
            name.removeLast(4)
        }

        let unsafe = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
            .union(.illegalCharacters)
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.hasSuffix("."),
              name.rangeOfCharacter(from: unsafe) == nil else {
            throw GPXRecordingError.invalidName
        }

        return name
    }
}

protocol GPXRecordingDraftStore: Sendable {
    func create(startedAt: Date) async throws
    func append(_ point: GPXRecordingPoint) async throws
    func beginSegment() async throws
    func recover() async throws -> GPXRecordingDraft?
    func discard() async throws
}

protocol GPXRecordingRepository: Sendable {
    func recordings() async throws -> [GPXRecordingFile]
    func nameExists(_ name: String) async throws -> Bool
    func save(gpx: String, named name: String) async throws -> GPXRecordingFile
    func prepareForSharing(_ file: GPXRecordingFile) async throws -> URL
}
