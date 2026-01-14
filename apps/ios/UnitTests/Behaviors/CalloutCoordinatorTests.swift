import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class CalloutCoordinatorTests: XCTestCase {

    func testInterruptWhilePlayingCompletesExactlyOnce() async {
        let playback = ControllableAudioPlayback()
        let geo = StubGeolocationManager()
        let motion = StubMotionActivity()
        let coordinator = CalloutCoordinator(audioPlayback: playback,
                                             geo: geo,
                                             motionActivityContext: motion,
                                             history: CalloutHistory())

        let completed = expectation(description: "Group completion observed")
        completed.assertForOverFulfill = true

        let delegate = TrackingCalloutGroupDelegate()

        var onCompleteCount = 0
        let group = CalloutGroup([StringCallout(.preview, "hello")], logContext: "test.interrupt")
        group.delegate = delegate
        group.onComplete = { _ in
            onCompleteCount += 1
            completed.fulfill()
        }

        let playStarted = expectation(description: "Audio playback started")
        await playback.setOnPlay { _ in
            playStarted.fulfill()
        }

        var result: Bool?
        let playFinished = expectation(description: "playCallouts returned")
        Task { @MainActor in
            result = await coordinator.playCallouts(group)
            playFinished.fulfill()
        }

        await fulfillment(of: [playStarted], timeout: 1.0)

        coordinator.interruptCurrent(clearQueue: false, playHush: true)

        await fulfillment(of: [completed, playFinished], timeout: 1.0)

        let counts = await playback.counts()

        XCTAssertEqual(onCompleteCount, 1)
        XCTAssertEqual(delegate.completedCount, 1)
        XCTAssertEqual(delegate.lastFinishedValue, false)
        XCTAssertEqual(counts.stop, 1)
        XCTAssertEqual(result, false)
    }

    func testClearPendingSkipsQueuedGroupsAndResumesContinuations() async {
        let playback = ControllableAudioPlayback()
        let geo = StubGeolocationManager()
        let motion = StubMotionActivity()
        let coordinator = CalloutCoordinator(audioPlayback: playback,
                                             geo: geo,
                                             motionActivityContext: motion,
                                             history: CalloutHistory())

        // Keep the first group "playing" so subsequent groups remain pending.
        let firstPlayStarted = expectation(description: "First group playback started")
        await playback.setOnPlay { _ in
            firstPlayStarted.fulfill()
        }

        let group1 = CalloutGroup([StringCallout(.preview, "g1")], logContext: "test.pending.g1")
        Task { @MainActor in
            _ = await coordinator.playCallouts(group1)
        }

        await fulfillment(of: [firstPlayStarted], timeout: 1.0)

        let skipped2 = expectation(description: "Group 2 skipped")
        skipped2.assertForOverFulfill = true
        let group2 = CalloutGroup([StringCallout(.preview, "g2")], logContext: "test.pending.g2")
        group2.onSkip = { skipped2.fulfill() }

        let skipped3 = expectation(description: "Group 3 skipped")
        skipped3.assertForOverFulfill = true
        let group3 = CalloutGroup([StringCallout(.preview, "g3")], logContext: "test.pending.g3")
        group3.onSkip = { skipped3.fulfill() }

        async let r2 = coordinator.playCallouts(group2)
        async let r3 = coordinator.playCallouts(group3)

        await Task.yield()
        coordinator.clearPending()

        let results = await (r2, r3)

        await fulfillment(of: [skipped2, skipped3], timeout: 1.0)
        XCTAssertEqual(results.0, false)
        XCTAssertEqual(results.1, false)

        let counts = await playback.counts()

        // Only the first group should have started playback.
        XCTAssertEqual(counts.play, 1)

        // Clean up the blocked first group.
        coordinator.interruptCurrent(clearQueue: true, playHush: false)
    }
}

// MARK: - Test doubles

private final class TrackingCalloutGroupDelegate: CalloutGroupDelegate {
    var completedCount = 0
    var lastFinishedValue: Bool?

    func isCalloutWithinRegionToLive(_ callout: CalloutProtocol) -> Bool { true }
    func calloutSkipped(_ callout: CalloutProtocol) { }
    func calloutStarting(_ callout: CalloutProtocol) { }
    func calloutFinished(_ callout: CalloutProtocol, completed: Bool) { }
    func calloutsSkipped(for group: CalloutGroup) { }
    func calloutsStarted(for group: CalloutGroup) { }

    func calloutsCompleted(for group: CalloutGroup, finished: Bool) {
        completedCount += 1
        lastFinishedValue = finished
    }
}

private final class StubMotionActivity: MotionActivityProtocol {
    var isWalking: Bool = false
    var isInVehicle: Bool = false
    var currentActivity: ActivityType = .unknown

    func startActivityUpdates() { }
    func stopActivityUpdates() { }
}

private final class StubGeolocationManager: GeolocationManagerProtocol {
    var isActive: Bool = false
    var coreLocationServicesEnabled: Bool = true
    var coreLocationAuthorizationStatus: CoreLocationAuthorizationStatus = .fullAccuracyLocationAuthorized

    weak var updateDelegate: GeolocationManagerUpdateDelegate?
    var location: CLLocation? = CLLocation(latitude: 47.0, longitude: -122.0)

    var collectionHeading: Heading = Heading(orderedBy: [.user], course: nil, deviceHeading: nil, userHeading: nil)
    var presentationHeading: Heading = Heading(orderedBy: [.user], course: nil, deviceHeading: nil, userHeading: nil)

    func heading(orderedBy types: [HeadingType]) -> Heading {
        Heading(orderedBy: types, course: nil, deviceHeading: nil, userHeading: nil)
    }

    func start() { }
    func stop() { }
    func snooze() { }

    func add(_ provider: LocationProvider) { }
    func remove(_ provider: LocationProvider) { }
    func add(_ provider: CourseProvider) { }
    func remove(_ provider: CourseProvider) { }
    func add(_ provider: UserHeadingProvider) { }
    func remove(_ provider: UserHeadingProvider) { }
}

private actor ControllableAudioPlayback: AudioPlaybackControlling {

    final class Token {
        private var continuation: CheckedContinuation<Bool, Never>?
        private var didResume = false

        init(_ continuation: CheckedContinuation<Bool, Never>) {
            self.continuation = continuation
        }

        func resumeOnce(_ value: Bool) {
            guard !didResume else { return }
            didResume = true
            let continuation = continuation
            self.continuation = nil
            continuation?.resume(returning: value)
        }
    }

    private var onPlay: (@Sendable (Sounds) -> Void)?

    private(set) var playCount: Int = 0
    private(set) var stopCount: Int = 0

    private var pendingTokens: [Token] = []

    func setOnPlay(_ handler: (@Sendable (Sounds) -> Void)?) {
        onPlay = handler
    }

    func counts() -> (play: Int, stop: Int) {
        (playCount, stopCount)
    }

    func play(_ sounds: Sounds) async -> Bool {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                playCount += 1
                onPlay?(sounds)
                pendingTokens.append(Token(continuation))
            }
        } onCancel: {
            Task { await self.cancelPendingPlays() }
        }
    }

    func play(_ sound: Sound) async -> Bool {
        await play(Sounds(sound))
    }

    func stopDiscreteAudio(hushSound: Sound?) async {
        stopCount += 1
        cancelPendingPlays()
    }

    func waitForDiscreteAudioSilence(timeout: TimeInterval) async {
        // No-op for tests; coordinator still calls this between groups.
    }

    func cancelPendingPlays() {
        let tokens = pendingTokens
        pendingTokens.removeAll()
        tokens.forEach { $0.resumeOnce(false) }
    }
}
