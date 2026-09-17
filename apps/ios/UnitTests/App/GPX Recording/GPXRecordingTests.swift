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

        let draft = GPXRecordingDraft(startedAt: Date(), segments: [[
            point(latitude: 51, longitude: -0.1, timestamp: Date())
        ]])
        _ = try await repository.save(draft: draft, named: "First")
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await repository.save(draft: draft, named: "Second")

        let files = try await repository.recordings()
        XCTAssertEqual(files.map(\.displayName), ["Second", "First"])
        let duplicateExists = try await repository.nameExists("sEcOnD.gpx")
        XCTAssertTrue(duplicateExists)
        await XCTAssertThrowsErrorAsync {
            _ = try await repository.save(draft: draft, named: "FIRST")
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
        XCTAssertEqual(controller.state, .stopping)

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
    func testSaveCompletesBeforeRefreshAfterSuccessfulCleanup() async {
        await checkSaveCompletion(cleanupFails: false, refreshFails: false)
    }

    @MainActor
    func testSaveCompletesBeforeRefreshAfterFailedCleanup() async {
        await checkSaveCompletion(cleanupFails: true, refreshFails: false)
    }

    @MainActor
    func testRefreshFailureDoesNotUndoSuccessfulSave() async {
        await checkSaveCompletion(cleanupFails: false, refreshFails: true)
    }

    @MainActor
    func testRefreshFailureDoesNotReplaceCleanupError() async {
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
        await controller.waitForPendingRefresh()
        controller.prepareRecoveredDraftForSaving()
        controller.proposedName = "Saved recording"
        controller.save()
        XCTAssertEqual(controller.state, .saving)
        for _ in 0..<3 {
            controller.save()
            controller.start()
            controller.discard()
        }
        XCTAssertEqual(controller.state, .saving)
        await fulfillment(of: [listingStarted], timeout: 5)
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertTrue(controller.isRefreshing)
        let saved = await repository.savedFiles
        XCTAssertEqual(saved.map(\.displayName), ["Saved recording"])
        XCTAssertEqual(controller.recordings, saved)
        await repository.release(2, result: refreshFails
            ? .failure(CocoaError(.fileReadNoPermission)) : .success(saved))
        await controller.waitForPendingRefresh()
        XCTAssertFalse(controller.isRefreshing)
        XCTAssertEqual(controller.recordings, saved)
        XCTAssertEqual(controller.pointCount, 0)
        let expectedError = cleanupFails ? CocoaError(.fileWriteNoPermission).localizedDescription : nil
        if case .storage(let message) = controller.error {
            XCTAssertEqual(message, expectedError)
        } else {
            XCTAssertNil(expectedError)
            XCTAssertNil(controller.error)
        }
        XCTAssertEqual(controller.refreshError,
                       refreshFails ? .storage(CocoaError(.fileReadNoPermission).localizedDescription) : nil)
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
                await controller.waitForPendingRefresh()
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
                let expectedError = controller.refreshError?.localizedDescription
                XCTAssertEqual(expectedFiles, latestFails ? [] : [latest])
                XCTAssertEqual(expectedError == nil, !latestFails)
                await repository.release(2, result: staleFails
                    ? .failure(CocoaError(.fileReadCorruptFile)) : .success([]))
                await fulfillment(of: [firstFinished], timeout: 5)
                XCTAssertEqual(controller.recordings, expectedFiles)
                XCTAssertEqual(controller.refreshError?.localizedDescription, expectedError)
                XCTAssertNil(controller.error)
            }
        }
    }

    @MainActor
    func testInitialLoadIgnoresListingSupersededByRefresh() async {
        for staleFails in [false, true] {
            let loadStarted = expectation(description: "Initial listing started")
            let refreshStarted = expectation(description: "Refresh started")
            let repository = ControlledRecordingRepository(starts: [1: loadStarted, 2: refreshStarted])
            addTeardownBlock { await repository.releaseAll() }
            let controller = GPXRecordingController(draftStore: SuspendedDraftStore(), repository: repository)
            await fulfillment(of: [loadStarted], timeout: 5)
            let refreshFinished = expectation(description: "Refresh finished")
            Task {
                await controller.refresh()
                refreshFinished.fulfill()
            }
            await fulfillment(of: [refreshStarted], timeout: 5)
            let latest = GPXRecordingFile(url: URL(fileURLWithPath: "/latest.gpx"), modifiedAt: Date())
            await repository.release(2, result: .success([latest]))
            await fulfillment(of: [refreshFinished], timeout: 5)
            XCTAssertEqual(controller.recordings, [latest])
            let stalePublished = expectation(description: "Initial listing must not publish over refresh")
            stalePublished.isInverted = true
            let filesSubscription = controller.$recordings.dropFirst().sink { _ in stalePublished.fulfill() }
            let errorSubscription = controller.$refreshError.compactMap { $0 }.sink { _ in stalePublished.fulfill() }
            await repository.release(1, result: staleFails
                ? .failure(CocoaError(.fileReadCorruptFile)) : .success([]))
            await fulfillment(of: [stalePublished], timeout: 0.1)
            filesSubscription.cancel()
            errorSubscription.cancel()
            XCTAssertEqual(controller.recordings, [latest])
            XCTAssertNil(controller.error)
        }
    }

    @MainActor
    func testSaveInvalidatesEarlierListingAndAllowsNewSessionDuringRefresh() async {
        for latestFails in [false, true] {
            let draftStore = RecordingDraftStore(
                draft: GPXRecordingDraft(startedAt: Date(), segments: [[
                    point(latitude: 51, longitude: -0.1, timestamp: Date())
                ]]), cleanupFails: false)
            let earlierStarted = expectation(description: "Pre-save listing started")
            let latestStarted = expectation(description: "Post-save listing started")
            let repository = ControlledRecordingRepository(starts: [2: earlierStarted, 3: latestStarted])
            addTeardownBlock { await repository.releaseAll() }
            let controller = GPXRecordingController(draftStore: draftStore, repository: repository)
            await waitForState(.recoverableInterruption, controller: controller)
            await controller.waitForPendingRefresh()
            let earlierFinished = expectation(description: "Pre-save listing finished")
            Task {
                await controller.refresh()
                earlierFinished.fulfill()
            }
            await fulfillment(of: [earlierStarted], timeout: 5)
            controller.prepareRecoveredDraftForSaving()
            controller.proposedName = "Saved recording"
            controller.save()
            await fulfillment(of: [latestStarted], timeout: 5)
            await controller.waitForPendingOperations()
            XCTAssertEqual(controller.state, .idle)
            let saved = await repository.savedFiles
            await repository.release(2, result: .success([]))
            await fulfillment(of: [earlierFinished], timeout: 5)
            XCTAssertEqual(controller.recordings, saved)
            controller.start()
            await controller.waitForPendingOperations()
            let newState = controller.state
            XCTAssertTrue(newState == .recording || newState == .paused)
            await repository.release(3, result: latestFails
                ? .failure(CocoaError(.fileReadNoPermission)) : .success(saved))
            await controller.waitForPendingRefresh()
            XCTAssertEqual(controller.state, newState)
            XCTAssertEqual(controller.recordings, saved)
            XCTAssertEqual(controller.refreshError == nil, !latestFails)
            XCTAssertNil(controller.error)
            XCTAssertEqual(controller.pointCount, 0)
        }
    }

    @MainActor
    func testStopDrainsAcceptedPointsAndRejectsLaterPoints() async throws {
        let store = ControlledDraftStore()
        addTeardownBlock { await store.releaseAll() }
        let controller = makeController(store: store)
        await controller.waitForPendingOperations()
        controller.start()
        await controller.waitForPendingOperations()
        let first = point(latitude: 51, longitude: 1, timestamp: Date())
        let second = point(latitude: 52, longitude: 2, timestamp: Date())
        let writing = expectation(description: "First point write suspended")
        await store.suspend(.append, started: writing)
        controller.capture(first)
        await fulfillment(of: [writing], timeout: 5)
        controller.capture(second)
        controller.stop()
        XCTAssertEqual(controller.state, .stopping)
        XCTAssertEqual(controller.pointCount, 0)
        controller.capture(point(latitude: 53, longitude: 3, timestamp: Date()))
        controller.start()
        controller.save()
        controller.discard()
        controller.stop()
        await store.release(.append)
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .awaitingName)
        XCTAssertEqual(controller.pointCount, 2)
        let draft = try await store.recover()
        XCTAssertEqual(draft?.segments, [[first, second]])
        let events = await store.events
        XCTAssertEqual(events.filter { $0 == .create }.count, 1)
        XCTAssertFalse(events.contains(.discard))
    }

    @MainActor
    func testResumeCannotOverrideStopOrSleepEvenWhenSegmentFails() async {
        for stopping in [false, true] {
            for segmentFails in [false, true] {
                let store = ControlledDraftStore()
                addTeardownBlock { await store.releaseAll() }
                let controller = makeController(store: store)
                await controller.waitForPendingOperations()
                controller.start()
                await controller.waitForPendingOperations()
                controller.capture(point(latitude: 51, longitude: 1, timestamp: Date()))
                await controller.waitForPendingOperations()
                controller.operationStateChanged(to: .sleep)
                let segmentStarted = expectation(description: "Resume segment suspended")
                await store.suspend(.segment, started: segmentStarted, fails: segmentFails)
                controller.operationStateChanged(to: .normal)
                await fulfillment(of: [segmentStarted], timeout: 5)
                if stopping {
                    controller.stop()
                } else {
                    controller.operationStateChanged(to: .sleep)
                }
                await store.release(.segment)
                await controller.waitForPendingOperations()
                XCTAssertEqual(controller.state, stopping ? .awaitingName : .paused)
                XCTAssertNil(controller.error)
                XCTAssertEqual(controller.pointCount, 1)

                if !stopping { controller.stop() }
                await controller.waitForPendingOperations()
                controller.discard()
                await controller.waitForPendingOperations()
                controller.operationStateChanged(to: .normal)
                controller.start()
                await controller.waitForPendingOperations()
                XCTAssertEqual(controller.state, .recording)
                XCTAssertEqual(controller.pointCount, 0)
                XCTAssertNil(controller.error)
            }
        }
    }

    @MainActor
    func testSegmentBoundaryFollowsAcceptedWrites() async throws {
        let store = ControlledDraftStore()
        addTeardownBlock { await store.releaseAll() }
        let controller = makeController(store: store)
        await controller.waitForPendingOperations()
        controller.start()
        await controller.waitForPendingOperations()
        let first = point(latitude: 51, longitude: 1, timestamp: Date())
        let second = point(latitude: 52, longitude: 2, timestamp: Date())
        let writing = expectation(description: "Point write suspended")
        await store.suspend(.append, started: writing)
        controller.capture(first)
        await fulfillment(of: [writing], timeout: 5)
        controller.operationStateChanged(to: .sleep)
        controller.capture(second) // Paused points are not accepted.
        controller.operationStateChanged(to: .normal)
        controller.capture(second) // Resume has not committed the segment yet.
        await store.release(.append)
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .recording)
        controller.capture(second)
        controller.stop()
        await controller.waitForPendingOperations()
        let draft = try await store.recover()
        XCTAssertEqual(draft?.segments, [[first], [second]])
        XCTAssertEqual(controller.pointCount, 2)
    }

    @MainActor
    func testDiscardReservesTransitionAndRestoresPreviousStateOnFailure() async {
        for naming in [false, true] {
            for fails in [false, true] {
                let store = ControlledDraftStore(draft: sampleDraft())
                addTeardownBlock { await store.releaseAll() }
                let repository = ControlledRecordingRepository(starts: [:])
                let controller = makeController(store: store, repository: repository)
                await controller.waitForPendingOperations()
                if naming { controller.prepareRecoveredDraftForSaving() }
                let deleting = expectation(description: "Discard suspended")
                await store.suspend(.discard, started: deleting, fails: fails)
                controller.discard()
                XCTAssertEqual(controller.state, .discarding)
                XCTAssertEqual(controller.isNamingPresented, naming)
                controller.save()
                controller.start()
                controller.discard()
                await fulfillment(of: [deleting], timeout: 5)
                controller.save()
                await store.release(.discard)
                await controller.waitForPendingOperations()
                XCTAssertEqual(controller.state, fails ? (naming ? .awaitingName : .recoverableInterruption) : .idle)
                XCTAssertEqual(controller.pointCount, fails ? 1 : 0)
                XCTAssertEqual(controller.error != nil, fails)
                XCTAssertEqual(controller.isNamingPresented, fails && naming)
                let files = await repository.savedFiles
                let events = await store.events
                XCTAssertTrue(files.isEmpty)
                XCTAssertEqual(events.filter { $0 == .discard }.count, 1)
                if fails {
                    controller.discard()
                    await controller.waitForPendingOperations()
                    XCTAssertEqual(controller.state, .idle)
                    XCTAssertNil(controller.error)
                }
            }
        }
    }

    @MainActor
    func testSaveBlocksDiscardUntilCleanupCompletes() async {
        let store = ControlledDraftStore(draft: sampleDraft())
        addTeardownBlock { await store.releaseAll() }
        let listing = expectation(description: "Reconciliation started")
        let earlierStarted = expectation(description: "Listing before commit started")
        let repository = ControlledRecordingRepository(starts: [2: earlierStarted, 3: listing])
        addTeardownBlock { await repository.releaseAll() }
        let controller = makeController(store: store, repository: repository)
        await controller.waitForPendingOperations()
        await controller.waitForPendingRefresh()
        let earlierFinished = expectation(description: "Listing before commit finished")
        Task {
            await controller.refresh()
            earlierFinished.fulfill()
        }
        await fulfillment(of: [earlierStarted], timeout: 5)
        controller.prepareRecoveredDraftForSaving()
        controller.proposedName = "Saved recording"
        let cleanup = expectation(description: "Cleanup suspended")
        await store.suspend(.discard, started: cleanup)
        controller.save()
        await fulfillment(of: [cleanup], timeout: 5)
        XCTAssertEqual(controller.state, .saving)
        XCTAssertEqual(controller.recordings.map(\.displayName), ["Saved recording"])
        await repository.release(2, result: .failure(CocoaError(.fileReadNoPermission)))
        await fulfillment(of: [earlierFinished], timeout: 5)
        await controller.waitForPendingRefresh()
        XCTAssertFalse(controller.isRefreshing)
        XCTAssertNil(controller.refreshError)
        XCTAssertEqual(controller.recordings.map(\.displayName), ["Saved recording"])
        controller.discard()
        controller.start()
        controller.save()
        await store.release(.discard)
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .idle)
        await fulfillment(of: [listing], timeout: 5)
        let saved = await repository.savedFiles
        XCTAssertEqual(saved.count, 1)
        let events = await store.events
        XCTAssertEqual(events.filter { $0 == .discard }.count, 1)
        await repository.release(3, result: .success(saved))
        await controller.waitForPendingRefresh()
    }

    @MainActor
    func testFailedPointIsNotCountedAndEmptyStopCleanupCanBeRetried() async {
        let store = ControlledDraftStore()
        let controller = makeController(store: store)
        await controller.waitForPendingOperations()
        controller.start()
        await controller.waitForPendingOperations()
        await store.failNext(.append)
        controller.capture(point(latitude: 51, longitude: 1, timestamp: Date()))
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.pointCount, 0)
        XCTAssertNotNil(controller.error)
        await store.failNext(.discard)
        controller.stop()
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .recoverableInterruption)
        controller.discard()
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.error)
    }

    @MainActor
    func testDuplicateSaveLeavesDraftAvailableForRetry() async {
        let store = ControlledDraftStore(draft: sampleDraft())
        let repository = FileGPXRecordingRepository(localRoot: makeTemporaryDirectory())
        let controller = makeController(store: store, repository: repository)
        await controller.waitForPendingOperations()
        _ = try? await repository.save(draft: sampleDraft(), named: "Existing")
        controller.prepareRecoveredDraftForSaving()
        controller.proposedName = "existing"
        controller.save()
        await controller.waitForPendingOperations()
        XCTAssertEqual(controller.state, .awaitingName)
        XCTAssertEqual(controller.error, .duplicateName)
        XCTAssertEqual(controller.pointCount, 1)
        controller.proposedName = "New"
        controller.save()
        await controller.waitForPendingOperations()
        await controller.waitForPendingRefresh()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(Set(controller.recordings.map(\.displayName)), Set(["Existing", "New"]))
    }

    @MainActor
    private func makeController(store: ControlledDraftStore,
                                repository: GPXRecordingRepository? = nil) -> GPXRecordingController {
        GPXRecordingController(draftStore: store,
                               repository: repository ?? FileGPXRecordingRepository(localRoot: makeTemporaryDirectory()),
                               initialOperationState: .normal,
                               observeEvents: false)
    }

    private func sampleDraft() -> GPXRecordingDraft {
        GPXRecordingDraft(startedAt: Date(), segments: [[
            point(latitude: 51, longitude: -0.1, timestamp: Date())
        ]])
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
        guard (listingCount > 1 || starts[1] != nil), !released else { return [] }
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

    func save(draft: GPXRecordingDraft, named name: String) async throws -> GPXRecordingFile {
        let file = GPXRecordingFile(url: URL(fileURLWithPath: "/\(name).gpx"), modifiedAt: Date())
        savedFiles.append(file)
        return file
    }

    func prepareForSharing(_ file: GPXRecordingFile) async throws -> URL { file.url }
}

private actor ControlledDraftStore: GPXRecordingDraftStore {
    enum Operation: Hashable { case create, append, segment, recover, discard }

    private var draft: GPXRecordingDraft?
    private var starts: [Operation: XCTestExpectation] = [:]
    private var failures: Set<Operation> = []
    private var continuations: [Operation: CheckedContinuation<Void, Error>] = [:]
    private var released = false
    private(set) var events: [Operation] = []

    init(draft: GPXRecordingDraft? = nil) { self.draft = draft }

    func suspend(_ operation: Operation, started: XCTestExpectation, fails: Bool = false) {
        starts[operation] = started
        if fails { failures.insert(operation) }
    }

    func failNext(_ operation: Operation) { failures.insert(operation) }

    func release(_ operation: Operation) {
        continuations.removeValue(forKey: operation)?.resume()
    }

    func releaseAll() {
        released = true
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending { continuation.resume(throwing: CancellationError()) }
    }

    private func perform(_ operation: Operation) async throws {
        events.append(operation)
        let fails = failures.remove(operation) != nil
        if let started = starts.removeValue(forKey: operation), !released {
            try await withCheckedThrowingContinuation { continuation in
                continuations[operation] = continuation
                started.fulfill()
            }
        }
        if fails { throw CocoaError(.fileWriteNoPermission) }
    }

    func create(startedAt: Date) async throws {
        try await perform(.create)
        draft = GPXRecordingDraft(startedAt: startedAt, segments: [[]])
    }

    func append(_ point: GPXRecordingPoint) async throws {
        try await perform(.append)
        guard let draft else { throw GPXRecordingError.draftUnavailable }
        var segments = draft.segments
        if segments.isEmpty { segments.append([]) }
        segments[segments.count - 1].append(point)
        self.draft = GPXRecordingDraft(startedAt: draft.startedAt, segments: segments)
    }

    func beginSegment() async throws {
        try await perform(.segment)
        guard let draft, draft.segments.last?.isEmpty == false else { return }
        self.draft = GPXRecordingDraft(startedAt: draft.startedAt, segments: draft.segments + [[]])
    }

    func recover() async throws -> GPXRecordingDraft? {
        try await perform(.recover)
        return draft
    }

    func discard() async throws {
        try await perform(.discard)
        draft = nil
    }
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
