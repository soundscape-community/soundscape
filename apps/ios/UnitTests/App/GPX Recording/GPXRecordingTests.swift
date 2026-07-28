//
//  GPXRecordingTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import CoreGPX
@testable import Soundscape

final class GPXRecordingTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testNameValidationNormalizesExtensionAndRejectsUnsafeNames() throws {
        XCTAssertEqual(try GPXRecordingNameValidator.normalizedName(" Morning walk.GPX "), "Morning walk")
        XCTAssertThrowsError(try GPXRecordingNameValidator.normalizedName(""))
        XCTAssertThrowsError(try GPXRecordingNameValidator.normalizedName("../walk"))
        XCTAssertThrowsError(try GPXRecordingNameValidator.normalizedName("walk:one"))
        XCTAssertThrowsError(try GPXRecordingNameValidator.normalizedName("walk."))
    }

    func testDraftRecoveryPreservesPointOrderAndSegments() async throws {
        let root = makeTemporaryDirectory()
        let store = FileGPXRecordingDraftStore(root: root)
        let first = point(latitude: 51, longitude: -0.1, timestamp: Date(timeIntervalSince1970: 1))
        let second = point(latitude: 52, longitude: -0.2, timestamp: Date(timeIntervalSince1970: 2))

        try await store.create(startedAt: Date(timeIntervalSince1970: 0))
        try await store.append(first)
        try await store.beginSegment()
        try await store.append(second)

        let recovered = try await store.recover()
        XCTAssertEqual(recovered?.segments, [[first], [second]])
        XCTAssertEqual(recovered?.pointCount, 2)
    }

    func testEmptySegmentIsNotDuplicated() async throws {
        let store = FileGPXRecordingDraftStore(root: makeTemporaryDirectory())
        try await store.create(startedAt: Date())
        try await store.beginSegment()

        let recovered = try await store.recover()
        XCTAssertEqual(recovered?.segments.count, 1)
        XCTAssertEqual(recovered?.pointCount, 0)
    }

    func testRepositoryCombinesLocationsNewestFirstAndDetectsGlobalDuplicate() async throws {
        let local = makeTemporaryDirectory()
        let cloud = makeTemporaryDirectory()
        let repository = FileGPXRecordingRepository(localRoot: local, cloudRootProvider: { cloud })

        _ = try await repository.save(gpx: "<gpx/>", named: "Local", to: .local)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await repository.save(gpx: "<gpx/>", named: "Cloud", to: .iCloud)

        let files = try await repository.recordings()
        XCTAssertEqual(files.map(\.displayName), ["Cloud", "Local"])
        XCTAssertEqual(files.map(\.storageLocation), [.iCloud, .local])
        let duplicateExists = try await repository.nameExists("cLoUd.gpx")
        XCTAssertTrue(duplicateExists)
        await XCTAssertThrowsErrorAsync {
            _ = try await repository.save(gpx: "<gpx/>", named: "LOCAL", to: .iCloud)
        }
    }

    func testRepositoryFallsBackToLocalWhenCloudUnavailable() async {
        let repository = FileGPXRecordingRepository(localRoot: makeTemporaryDirectory(),
                                                    cloudRootProvider: { nil })
        let location = await repository.preferredStorageLocation()
        XCTAssertEqual(location, .local)
    }

    @MainActor
    func testRepeatedStartCreatesOnlyOneDraft() async throws {
        let draftStore = SuspendedDraftStore()
        let repository = FileGPXRecordingRepository(localRoot: makeTemporaryDirectory(),
                                                    cloudRootProvider: { nil })
        let controller = GPXRecordingController(draftStore: draftStore, repository: repository)

        await waitForState(.idle, controller: controller)
        controller.start()
        controller.start()

        XCTAssertEqual(controller.state, .starting)
        let createCount = await waitForCreateCount(draftStore)
        XCTAssertEqual(createCount, 1)

        await draftStore.finishCreating()
        await waitUntil(controller: controller) {
            $0.state == .recording || $0.state == .paused
        }
    }

    func testGPXBuilderCreatesOneTrackWithSegmentsAndCorrectBounds() throws {
        let first = point(latitude: 10, longitude: 100, timestamp: Date(timeIntervalSince1970: 1))
        let second = point(latitude: 20, longitude: -30, timestamp: Date(timeIntervalSince1970: 2))
        let draft = GPXRecordingDraft(startedAt: Date(), segments: [[first], [second]])

        let document = GPXRecordingDocumentBuilder.makeGPX(from: draft)
        let parsed = GPXParser(withRawString: document)?.parsedData()

        XCTAssertEqual(parsed?.tracks.count, 1)
        XCTAssertEqual(parsed?.tracks.first?.segments.count, 2)
        XCTAssertEqual(parsed?.metadata?.bounds?.minLatitude, 10)
        XCTAssertEqual(parsed?.metadata?.bounds?.maxLatitude, 20)
        XCTAssertEqual(parsed?.metadata?.bounds?.minLongitude, -30)
        XCTAssertEqual(parsed?.metadata?.bounds?.maxLongitude, 100)

        let parsedPoint = parsed?.tracks.first?.segments.first?.points.first?.gpxLocation()
        XCTAssertEqual(parsedPoint?.location.horizontalAccuracy, 3)
        XCTAssertEqual(parsedPoint?.deviceHeading, 45)
        XCTAssertEqual(parsedPoint?.activity, "walking")
    }

    private func point(latitude: Double, longitude: Double, timestamp: Date) -> GPXRecordingPoint {
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                  altitude: 12,
                                  horizontalAccuracy: 3,
                                  verticalAccuracy: 4,
                                  course: 90,
                                  speed: 1.5,
                                  timestamp: timestamp)
        return GPXRecordingPoint(location: location, heading: 45, motionActivity: "walking")
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPXRecordingTests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    @MainActor
    private func waitForState(_ state: GPXRecordingState,
                              controller: GPXRecordingController) async {
        await waitUntil(controller: controller) { $0.state == state }
    }

    @MainActor
    private func waitUntil(controller: GPXRecordingController,
                           condition: (GPXRecordingController) -> Bool) async {
        for _ in 0..<100 where !condition(controller) {
            await Task.yield()
        }
        XCTAssertTrue(condition(controller))
    }

    private func waitForCreateCount(_ draftStore: SuspendedDraftStore) async -> Int {
        for _ in 0..<100 {
            let count = await draftStore.createCount
            if count > 0 {
                return count
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return await draftStore.createCount
    }
}

private actor SuspendedDraftStore: GPXRecordingDraftStore {
    private(set) var createCount = 0
    private var createContinuation: CheckedContinuation<Void, Never>?

    func create(startedAt: Date) async throws {
        createCount += 1
        await withCheckedContinuation { continuation in
            createContinuation = continuation
        }
    }

    func append(_ point: GPXRecordingPoint) async throws {}

    func beginSegment() async throws {}

    func recover() async throws -> GPXRecordingDraft? {
        nil
    }

    func discard() async throws {}

    func finishCreating() {
        createContinuation?.resume()
        createContinuation = nil
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        // Expected.
    }
}
