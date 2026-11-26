//
//  AudioEngineTest.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFAudio
import XCTest
@testable import Soundscape

class TestAudioEnvironmentSettings: EnvironmentSettingsProvider {
    var envRenderingAlgorithm: AVAudio3DMixingRenderingAlgorithm = .auto
    var envRenderingDistance: Double = 40
    var envRenderingReverbEnable: Bool = false
    var envRenderingReverbPreset: AVAudioUnitReverbPreset = .mediumRoom
    var envRenderingReverbBlend: Float = 0
    var envRenderingReverbLevel: Float = 0
    var envReverbFilterActive: Bool = false
    var envReverbFilterBandwidth: Float = 0
    var envReverbFilterBypass: Bool = true
    var envReverbFilterType: AVAudioUnitEQFilterType = .parametric
    var envReverbFilterFrequency: Float = 0
    var envReverbFilterGain: Float = 0
}

final class AudioEngineTest: XCTestCase {
    func testHapticPulseAudioVolumeIsSymmetric() {
        let expectedVolumes = [
            (offset: 0.0, volume: 1.0),
            (offset: 15.0, volume: 1.0),
            (offset: 22.5, volume: 0.5),
            (offset: 30.0, volume: 0.0),
            (offset: 35.0, volume: 0.0)
        ]

        for beaconBearing in [0.0, 90.0, 180.0, 270.0] {
            for (offset, expectedVolume) in expectedVolumes {
                let counterClockwiseHeading = beaconBearing.add(degrees: -offset)
                let clockwiseHeading = beaconBearing.add(degrees: offset)
                let counterClockwiseVolume = HapticPulseBeacon.audioVolume(userHeading: counterClockwiseHeading,
                                                                            beaconBearing: beaconBearing,
                                                                            fullVolumeAngle: 15.0)
                let clockwiseVolume = HapticPulseBeacon.audioVolume(userHeading: clockwiseHeading,
                                                                     beaconBearing: beaconBearing,
                                                                     fullVolumeAngle: 15.0)

                XCTAssertEqual(counterClockwiseVolume, clockwiseVolume, accuracy: 0.0001,
                               "Volume differs at bearing \(beaconBearing) and offset \(offset)")
                XCTAssertEqual(counterClockwiseVolume, Float(expectedVolume), accuracy: 0.0001,
                               "Unexpected volume at bearing \(beaconBearing) and offset \(offset)")
            }
        }
    }

    func testCompletionIsStoredAndOnlyResolvedOnce() async {
        let state = PlaybackCompletion()
        let handle = PlaybackHandle(state: state) { _ in }
        async let first = handle.completion()
        async let second = handle.completion()
        state.resolve(.interrupted)
        state.resolve(.completed)
        let values = await [first, second, handle.completion()]
        XCTAssertEqual(values, [.interrupted, .interrupted, .interrupted])
    }

    func testBeatTimingUsesIntroAndPhrasePosition() {
        let timing = BeaconTiming(intro: 720, phrase: 960, beats: 4)
        XCTAssertEqual(timing.next(after: nil).start, 720)
        XCTAssertEqual(timing.next(after: 200).start, 720)
        XCTAssertEqual(timing.next(after: 720).start, 960)
        XCTAssertEqual(timing.next(after: 960).offset, 480)
        XCTAssertEqual(timing.next(after: 1679).start, 1680)
        XCTAssertEqual(timing.next(after: 1679).offset, 0)
        XCTAssertEqual(timing.next(after: 1690).offset, 240)
    }

    func testPositionSeparatesCompassAndListenerRelativeBearings() {
        let listener = AudioCoordinate(latitude: 50, longitude: 0)
        let target = AudioCoordinate(latitude: 50, longitude: 0.01)
        XCTAssertEqual(SoundType.compass(45, .ring).position(listener: listener, heading: 90, ring: 15)?.bearing, 45)
        XCTAssertEqual(SoundType.relative(45, .ring).position(listener: listener, heading: 90, ring: 15)?.bearing, 135)
        XCTAssertEqual(SoundType.localized(target, .ring).position(listener: listener, heading: 90, ring: 15)?.distance, 15)
        XCTAssertGreaterThan(SoundType.localized(target, .real).position(listener: listener, heading: 90, ring: 15)?.distance ?? 0, 500)
    }

    @MainActor
    func testOverlappingPlaybackOfOneDescriptionStopsIndependently() async throws {
        let url = try makeAudioFile(duration: 0.20)
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true, canStart: { true })
        engine.start()
        let layered = try XCTUnwrap(LayeredSound(GenericSound(url, direction: 15), GenericSound(url, direction: 15)))
        let first = engine.play(layered)
        let second = engine.play(layered)
        first.stop()
        let stopped = await first.completion()
        XCTAssertEqual(stopped, .stopped)
        await assertPlayback(second, result: .completed)
    }

    @MainActor
    func testFinishDuringBeaconPreparationWaitsForOutro() async throws {
        let phrase = try makeAudioFile(duration: 0.08)
        let outro = try makeAudioFile(duration: 0.15)
        defer {
            try? FileManager.default.removeItem(at: phrase)
            try? FileManager.default.removeItem(at: outro)
        }
        let asset = AudioAsset.file(phrase)
        let beacon = TestBeaconSound(content: .beacon(AdaptiveBeacon(
            assets: [asset], reference: AudioCoordinate(latitude: 0, longitude: 0),
            beats: 2, intro: nil, outro: .file(outro), select: { _, _, _, _ in (asset, 1) })))
        let engine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true, canStart: { true })
        engine.start()
        let handle = engine.play(beacon)
        let start = ContinuousClock.now
        handle.finish()
        await assertPlayback(handle, result: .completed)
        XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(100))
    }

    @MainActor
    func testStoppingSpeechDiscardsLatePCM() async {
        let preparing = expectation(description: "synthesizer started")
        let cancelled = expectation(description: "synthesizer cancelled")
        let speech = DelayedSpeech(preparing: preparing, cancelled: cancelled)
        let engine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true,
                                 canStart: { true }, makeSpeech: { _, _, output in
            speech.setOutput(output)
            return speech
        })
        engine.start()
        let handle = engine.play(TTSSound("cancel while preparing"))
        await fulfillment(of: [preparing], timeout: 5)
        handle.stop()
        await fulfillment(of: [cancelled], timeout: 5)
        speech.emitLateAudio()
        let result = await handle.completion()
        XCTAssertEqual(result, .stopped)
        XCTAssertFalse(engine.hasTransientAudio)
    }

    @MainActor
    private func assertPlayback(_ handle: PlaybackHandle, result: PlaybackResult) async {
        let completed = expectation(description: "playback finished")
        Task {
            let actual = await handle.completion()
            XCTAssertEqual(actual, result)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 5)
        handle.stop()
    }

    private func makeAudioFile(duration: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        pcm.frameLength = frames
        pcm.floatChannelData?[0].update(repeating: 0, count: Int(frames))
        try file.write(from: pcm)
        return url
    }

    func testStopBeforePreparationAndIndependentOperations() async {
        let playback = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true)
        let sound = TestAudioSound()
        let first = playback.play(sound)
        first.stop()
        let result = await first.completion()
        XCTAssertEqual(result, .stopped)

        let second = playback.play(sound)
        XCTAssertNotEqual(first, second)
        let failure = await second.completion()
        guard case .failed = failure else { return XCTFail("Expected an unavailable engine to fail") }
    }
}

private struct TestBeaconSound: Sound {
    let type = SoundType.standard
    let content: SoundContent
    let description = "test beacon"
}

private struct TestAudioSound: Sound {
    let type = SoundType.standard
    let content = SoundContent.asset(.bundle(name: "testMissingAsset", extension: "wav"))
    let description = "test sound"
}

@MainActor
private final class MockPlayback: AudioPlayback {
    private(set) var operations: [PlaybackCompletion] = []
    private(set) var stops = 0

    nonisolated func play(_ request: AudioRequest) -> PlaybackHandle {
        MainActor.assumeIsolated {
            let state = PlaybackCompletion()
            operations.append(state)
            return PlaybackHandle(state: state) { [weak self] command in
                guard case .stop = command else { return }
                MainActor.assumeIsolated {
                    self?.stops += 1
                    state.resolve(.stopped)
                }
            }
        }
    }

    nonisolated var hasTransientAudio: Bool { false }
    nonisolated func stopTransientAudio() {}
}

final class CalloutCoordinatorTest: XCTestCase {
    @MainActor
    func testClearSkipsPendingAndInterruptDoesNotAdvanceStalePlayback() async {
        let playback = MockPlayback()
        let coordinator = CalloutCoordinator(playback: playback, legacy: CalloutContext(
            prefix: { _ in .empty }, sounds: { _, _ in Sounds(TestAudioSound()) }, record: { _ in }))
        let firstStopped = expectation(description: "first interrupted")
        let lastStarted = expectation(description: "replacement started")
        let lastCompleted = expectation(description: "replacement completed")

        let first = CalloutGroup([StringCallout(.system, "first")], logContext: "test")
        first.onComplete = { result in
            XCTAssertFalse(result)
            firstStopped.fulfill()
        }
        let pending = CalloutGroup([StringCallout(.system, "pending")], logContext: "test")
        pending.onStart = { XCTFail("cleared group started") }
        let replacement = CalloutGroup([StringCallout(.system, "replacement")], action: .interruptAndClear, logContext: "test")
        replacement.onStart = { lastStarted.fulfill() }
        replacement.onComplete = { result in
            XCTAssertTrue(result)
            lastCompleted.fulfill()
        }

        coordinator.enqueue(first)
        coordinator.enqueue(pending)
        coordinator.enqueue(replacement)
        await fulfillment(of: [firstStopped, lastStarted], timeout: 2, enforceOrder: true)
        XCTAssertEqual(playback.stops, 1)
        XCTAssertEqual(playback.operations.count, 2)

        playback.operations[0].resolve(.completed)
        playback.operations[1].resolve(.completed)
        await fulfillment(of: [lastCompleted], timeout: 2)
    }
    @MainActor
    func testInterruptedDelayCannotAdvanceReplacementGroup() async {
        let playback = MockPlayback()
        let delay = ControlledDelay()
        let delayStarted = expectation(description: "delay requested")
        let coordinator = CalloutCoordinator(playback: playback, legacy: CalloutContext(
            prefix: { _ in .empty }, sounds: { _, _ in Sounds(TestAudioSound()) }, record: { _ in }),
            delay: { _ in await delay.wait(started: delayStarted) })
        let first = CalloutGroup([StringCallout(.system, "first"), StringCallout(.system, "old second")],
                                 calloutDelay: 30, logContext: "test")
        let replacement = CalloutGroup([StringCallout(.system, "replacement")], logContext: "test")
        let lastCompleted = expectation(description: "replacement completed")
        replacement.onComplete = { result in
            XCTAssertTrue(result)
            lastCompleted.fulfill()
        }

        coordinator.enqueue(first)
        playback.operations[0].resolve(.completed)
        await fulfillment(of: [delayStarted], timeout: 2)
        coordinator.interruptCurrent(clearPending: true, hush: false)
        coordinator.enqueue(replacement)
        await delay.fire()
        playback.operations[1].resolve(.completed)
        await fulfillment(of: [lastCompleted], timeout: 2)
        XCTAssertEqual(playback.operations.count, 2)
    }

}


private actor ControlledDelay {
    private var continuation: CheckedContinuation<Void, Never>?
    func wait(started: XCTestExpectation) async {
        await withCheckedContinuation {
            continuation = $0
            started.fulfill()
        }
    }
    func fire() {
        continuation?.resume()
        continuation = nil
    }
}


// A lock allows the test to deliver a deliberately late Apple-style callback after cancellation.
private final class DelayedSpeech: SpeechPCMSource, @unchecked Sendable {
    let preparing: XCTestExpectation
    let cancelled: XCTestExpectation
    private let lock = NSLock()
    private var output: SpeechPCMOutput?

    init(preparing: XCTestExpectation, cancelled: XCTestExpectation) {
        self.preparing = preparing
        self.cancelled = cancelled
    }

    func setOutput(_ output: @escaping SpeechPCMOutput) { lock.withLock { self.output = output } }
    func start() { preparing.fulfill() }
    func pause() {}
    func resume() {}
    func cancel() { cancelled.fulfill() }

    func emitLateAudio() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1),
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256) else { return }
        pcm.frameLength = 256
        let receive = lock.withLock { output }
        receive?(.success(pcm))
        receive?(.success(nil))
    }
}
