//
//  GPXRecordingTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
import Combine
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
        XCTAssertThrowsError(try GPXRecordingNameValidator.normalizedName(".walk"))
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

    func testDraftRecoveryIgnoresMalformedUnterminatedTrailingEntry() async throws {
        let root = makeTemporaryDirectory()
        let store = FileGPXRecordingDraftStore(root: root)
        let first = point(latitude: 51, longitude: -0.1, timestamp: Date(timeIntervalSince1970: 1))

        try await store.create(startedAt: Date(timeIntervalSince1970: 0))
        try await store.append(first)
        try append(Data(#"{"type":"point""#.utf8),
                   to: draftEntriesURL(root: root))

        let recovered = try await store.recover()
        XCTAssertEqual(recovered?.segments, [[first]])
        XCTAssertEqual(recovered?.pointCount, 1)
    }

    func testDraftRecoveryRejectsMalformedCompletedEntry() async throws {
        let root = makeTemporaryDirectory()
        let store = FileGPXRecordingDraftStore(root: root)

        try await store.create(startedAt: Date(timeIntervalSince1970: 0))
        try append(Data("not-json\n".utf8),
                   to: draftEntriesURL(root: root))

        await XCTAssertThrowsErrorAsync {
            _ = try await store.recover()
        }
    }

    func testRepositoryListsLocalFilesNewestFirstAndDetectsDuplicate() async throws {
        let local = makeTemporaryDirectory()
        let repository = FileGPXRecordingRepository(localRoot: local)

        _ = try await repository.save(gpx: "<gpx/>", named: "First")
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await repository.save(gpx: "<gpx/>", named: "Second")

        let files = try await repository.recordings()
        XCTAssertEqual(files.map(\.displayName), ["Second", "First"])
        let duplicateExists = try await repository.nameExists("sEcOnD.gpx")
        XCTAssertTrue(duplicateExists)
        await XCTAssertThrowsErrorAsync {
            _ = try await repository.save(gpx: "<gpx/>", named: "FIRST")
        }
    }

    @MainActor
    func testRepeatedStartCreatesOnlyOneDraft() async throws {
        let draftStore = SuspendedDraftStore()
        let repository = FileGPXRecordingRepository(localRoot: makeTemporaryDirectory())
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

    @MainActor
    func testStoppingWithoutPointsDiscardsDraftAndReturnsToIdle() async throws {
        let draftStore = SuspendedDraftStore()
        let repository = FileGPXRecordingRepository(localRoot: makeTemporaryDirectory())
        let controller = GPXRecordingController(draftStore: draftStore, repository: repository)

        await waitForState(.idle, controller: controller)
        controller.start()
        _ = await waitForCreateCount(draftStore)
        await draftStore.finishCreating()
        await waitUntil(controller: controller) {
            $0.state == .recording || $0.state == .paused
        }

        controller.stop()
        XCTAssertEqual(controller.state, .starting)

        await waitForState(.idle, controller: controller)
        let discardCount = await draftStore.discardCount
        XCTAssertEqual(discardCount, 1)
        XCTAssertEqual(controller.pointCount, 0)
        XCTAssertNil(controller.error)
    }

    @MainActor
    func testSuccessfulSaveRemainsCompleteWhenDraftCleanupFails() async throws {
        let draftStore = FailingDiscardDraftStore(
            draft: GPXRecordingDraft(startedAt: Date(),
                                     segments: [[point(latitude: 51,
                                                       longitude: -0.1,
                                                       timestamp: Date())]])
        )
        let repository = FileGPXRecordingRepository(localRoot: makeTemporaryDirectory())
        let controller = GPXRecordingController(draftStore: draftStore, repository: repository)

        await waitForState(.recoverableInterruption, controller: controller)
        controller.prepareRecoveredDraftForSaving()
        controller.proposedName = "Saved recording"
        controller.save()

        await waitForState(.idle, controller: controller)
        XCTAssertEqual(controller.recordings.map(\.displayName), ["Saved recording"])
        XCTAssertEqual(controller.pointCount, 0)
        XCTAssertNotNil(controller.error)
    }

    @MainActor
    func testSaveWaitsForRefreshAfterSuccessfulCleanup() async {
        await checkSaveCompletion(cleanupFails: false, refreshFails: false)
    }

    @MainActor
    func testSaveWaitsForRefreshAfterFailedCleanup() async {
        await checkSaveCompletion(cleanupFails: true, refreshFails: false)
    }

    @MainActor
    func testRefreshFailureDoesNotUndoSuccessfulSave() async {
        await checkSaveCompletion(cleanupFails: false, refreshFails: true)
    }

    @MainActor
    func testRefreshFailureReplacesCleanupError() async {
        await checkSaveCompletion(cleanupFails: true, refreshFails: true)
    }

    @MainActor
    private func checkSaveCompletion(cleanupFails: Bool, refreshFails: Bool) async {
        let draftStore = RecordingDraftStore(
            draft: GPXRecordingDraft(startedAt: Date(), segments: [[
                point(latitude: 51, longitude: -0.1, timestamp: Date())
            ]]), cleanupFails: cleanupFails)
        let listingStarted = expectation(description: "Post-save listing started")
        let repository = ControlledRecordingRepository(starts: [2: listingStarted])
        addTeardownBlock { await repository.releaseAll() }
        let controller = GPXRecordingController(draftStore: draftStore, repository: repository)
        await waitForState(.recoverableInterruption, controller: controller)
        controller.prepareRecoveredDraftForSaving()
        controller.proposedName = "Saved recording"
        // The queued discard must recheck state when its task begins.
        controller.discard()
        controller.save()
        await fulfillment(of: [listingStarted], timeout: 5)
        XCTAssertEqual(controller.state, .saving)
        XCTAssertTrue(controller.recordings.isEmpty)
        for _ in 0..<3 {
            controller.save()
            controller.start()
            controller.discard()
        }
        XCTAssertEqual(controller.state, .saving)
        let saved = await repository.savedFiles
        XCTAssertEqual(saved.map(\.displayName), ["Saved recording"])
        await repository.release(2, result: refreshFails
            ? .failure(CocoaError(.fileReadNoPermission)) : .success(saved))
        await waitForState(.idle, controller: controller)
        XCTAssertEqual(controller.recordings, refreshFails ? [] : saved)
        XCTAssertEqual(controller.pointCount, 0)
        let expectedError = refreshFails ? CocoaError(.fileReadNoPermission).localizedDescription
            : cleanupFails ? CocoaError(.fileWriteNoPermission).localizedDescription : nil
        if case .storage(let message) = controller.error {
            XCTAssertEqual(message, expectedError)
        } else {
            XCTAssertNil(expectedError)
            XCTAssertNil(controller.error)
        }
        controller.save()
        let writeCount = await repository.savedFiles.count
        let createCount = await draftStore.createCount
        let discardCount = await draftStore.discardCount
        XCTAssertEqual(writeCount, 1)
        XCTAssertEqual(createCount, 0)
        XCTAssertEqual(discardCount, 1)
    }

    @MainActor
    func testOverlappingRefreshIgnoresStaleResultsAndErrors() async {
        for staleFails in [false, true] {
            for latestFails in [false, true] {
                let firstStarted = expectation(description: "Earlier refresh started")
                let secondStarted = expectation(description: "Latest refresh started")
                let repository = ControlledRecordingRepository(starts: [2: firstStarted, 3: secondStarted])
                addTeardownBlock { await repository.releaseAll() }
                let controller = GPXRecordingController(draftStore: SuspendedDraftStore(), repository: repository)
                await waitForState(.idle, controller: controller)
                let firstFinished = expectation(description: "Earlier refresh finished")
                Task {
                    await controller.refresh()
                    firstFinished.fulfill()
                }
                await fulfillment(of: [firstStarted], timeout: 5)
                let secondFinished = expectation(description: "Latest refresh finished")
                Task {
                    await controller.refresh()
                    secondFinished.fulfill()
                }
                await fulfillment(of: [secondStarted], timeout: 5)
                let latest = GPXRecordingFile(url: URL(fileURLWithPath: "/latest.gpx"), modifiedAt: Date())
                await repository.release(3, result: latestFails
                    ? .failure(CocoaError(.fileReadNoPermission)) : .success([latest]))
                await fulfillment(of: [secondFinished], timeout: 5)
                let expectedFiles = controller.recordings
                let expectedError = controller.error?.localizedDescription
                XCTAssertEqual(expectedFiles, latestFails ? [] : [latest])
                XCTAssertEqual(expectedError == nil, !latestFails)
                await repository.release(2, result: staleFails
                    ? .failure(CocoaError(.fileReadCorruptFile)) : .success([]))
                await fulfillment(of: [firstFinished], timeout: 5)
                XCTAssertEqual(controller.recordings, expectedFiles)
                XCTAssertEqual(controller.error?.localizedDescription, expectedError)
            }
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

    private func draftEntriesURL(root: URL) -> URL {
        root.appendingPathComponent("GPX Recording Draft", isDirectory: true)
            .appendingPathComponent("entries.jsonl")
    }

    private func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    @MainActor
    private func waitForState(_ state: GPXRecordingState,
                              controller: GPXRecordingController) async {
        let reachedState = expectation(description: "Reached \(state)")
        let subscription = controller.$state.filter { $0 == state }.prefix(1).sink { _ in
            reachedState.fulfill()
        }
        defer { subscription.cancel() }
        await fulfillment(of: [reachedState], timeout: 5)
        XCTAssertEqual(controller.state, state)
    }

    @MainActor
    private func waitUntil(controller: GPXRecordingController,
                           condition: (GPXRecordingController) -> Bool) async {
        for _ in 0..<100 where !condition(controller) {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 1_000_000)
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

private actor FailingDiscardDraftStore: GPXRecordingDraftStore {
    private let draft: GPXRecordingDraft

    init(draft: GPXRecordingDraft) {
        self.draft = draft
    }

    func create(startedAt: Date) async throws {}

    func append(_ point: GPXRecordingPoint) async throws {}

    func beginSegment() async throws {}

    func recover() async throws -> GPXRecordingDraft? {
        draft
    }

    func discard() async throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}

private actor SuspendedDraftStore: GPXRecordingDraftStore {
    private(set) var createCount = 0
    private(set) var discardCount = 0
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

    func discard() async throws {
        discardCount += 1
    }

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

private actor ControlledRecordingRepository: GPXRecordingRepository {
    private let starts: [Int: XCTestExpectation]
    private var listingCount = 0
    private var continuations: [Int: CheckedContinuation<[GPXRecordingFile], Error>] = [:]
    private var released = false
    private(set) var savedFiles: [GPXRecordingFile] = []

    init(starts: [Int: XCTestExpectation]) {
        self.starts = starts
    }

    func recordings() async throws -> [GPXRecordingFile] {
        listingCount += 1
        guard listingCount > 1, !released else { return [] }
        let request = listingCount
        return try await withCheckedThrowingContinuation { continuation in
            continuations[request] = continuation
            starts[request]?.fulfill()
        }
    }

    func release(_ request: Int, result: Result<[GPXRecordingFile], Error>) {
        continuations.removeValue(forKey: request)?.resume(with: result)
    }

    func releaseAll() {
        released = true
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending {
            continuation.resume(throwing: CancellationError())
        }
    }

    func nameExists(_ name: String) async throws -> Bool { false }

    func save(gpx: String, named name: String) async throws -> GPXRecordingFile {
        let file = GPXRecordingFile(url: URL(fileURLWithPath: "/\(name).gpx"), modifiedAt: Date())
        savedFiles.append(file)
        return file
    }

    func prepareForSharing(_ file: GPXRecordingFile) async throws -> URL { file.url }
}

private actor RecordingDraftStore: GPXRecordingDraftStore {
    private var draft: GPXRecordingDraft?
    private let cleanupFails: Bool
    private(set) var createCount = 0
    private(set) var discardCount = 0

    init(draft: GPXRecordingDraft, cleanupFails: Bool) {
        self.draft = draft
        self.cleanupFails = cleanupFails
    }

    func create(startedAt: Date) async throws { createCount += 1 }
    func append(_ point: GPXRecordingPoint) async throws {}
    func beginSegment() async throws {}
    func recover() async throws -> GPXRecordingDraft? { draft }

    func discard() async throws {
        discardCount += 1
        if cleanupFails { throw CocoaError(.fileWriteNoPermission) }
        draft = nil
    }
}
