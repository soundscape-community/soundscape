//
//  CalloutStateMachine.swift
//  Soundscape
//
//  This class manages the callout of a list of callouts, one after another,
//  with the ability to hush or restart the whole set of callouts.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation
import Foundation

@MainActor
protocol CalloutStateMachineDelegate: AnyObject {
    func calloutsDidFinish(id: UUID)
}

@MainActor
final class CalloutStateMachine {

    private enum State: CustomStringConvertible {
        case off
        case running
        case stopping
        case completed
        case failed

        var description: String {
            switch self {
            case .off: return "off"
            case .running: return "running"
            case .stopping: return "stopping"
            case .completed: return "completed"
            case .failed: return "failed"
            }
        }
    }

    // MARK: Properties

    weak var delegate: CalloutStateMachineDelegate?

    private weak var geo: GeolocationManagerProtocol?
    private weak var history: CalloutHistory?
    private weak var motionActivityContext: MotionActivityProtocol?
    private weak var audioEngine: AudioEngineProtocol?

    private var state: State = .off
    private var hushed = false
    private var pendingHushSound: Sound?
    private var calloutGroup: CalloutGroup?
    private var calloutIterator: IndexingIterator<[CalloutProtocol]>?
    private var calloutTask: Task<Void, Never>?
    private var didNotifyCompletion = false
    private let idleSignal = IdleSignal()
    private static let silencePollInterval: UInt64 = 20_000_000

    init(audioEngine engine: AudioEngineProtocol,
         geo: GeolocationManagerProtocol,
         motionActivityContext motion: MotionActivityProtocol,
         history calloutHistory: CalloutHistory) {
        audioEngine = engine
        self.geo = geo
        motionActivityContext = motion
        history = calloutHistory
    }

    // MARK: Methods

    @discardableResult
    func start(_ callouts: CalloutGroup) -> Task<Void, Never> {
        Task { @MainActor in
            await startCallouts(callouts)
        }
    }

    @discardableResult
    func hush(playSound: Bool = false) -> Task<Void, Never> {
        Task { @MainActor in
            await hushCallouts(playSound: playSound)
        }
    }

    @discardableResult
    func stop() -> Task<Void, Never> {
        Task { @MainActor in
            await stopCallouts()
        }
    }

    class func log(callout: CalloutProtocol, context: String?) {
        var properties = ["type": callout.logCategory,
                          "activity": AppContext.shared.motionActivityContext.currentActivity.rawValue,
                          "audio.output": AppContext.shared.audioEngine.outputType]

        if let context =  context {
            properties["context"] = context
        }

        GDATelemetry.track("callout", with: properties)
    }

    private func startCallouts(_ callouts: CalloutGroup) async {
        if state != .off {
            await waitUntilIdle()
        }

        guard state == .off else {
            GDLogVerbose(.stateMachine, "Unable to start callout group. State machine is currently in state: \(state)")
            return
        }

        calloutGroup = callouts
        calloutIterator = callouts.callouts.makeIterator()
        hushed = false
        didNotifyCompletion = false
        state = .running

        calloutTask = Task { @MainActor in
            await self.execute(callouts)
        }
    }

    private func hushCallouts(playSound: Bool) async {
        await cancelCurrentCallouts(markHushed: true, hushSound: playSound ? GlyphSound(.exitMode) : nil)
    }

    private func stopCallouts() async {
        await cancelCurrentCallouts(markHushed: false, hushSound: nil)
    }

    // MARK: Execution

    private func execute(_ group: CalloutGroup) async {
        group.onStart?()
        group.delegate?.calloutsStarted(for: group)

        if group.stopSoundsBeforePlaying {
            await stopDiscreteAudio(play: nil)
        }

        guard await playPrelude(for: group) else {
            notifyCompletion(false)
            await finish(failed: true)
            return
        }

        await runCallouts(in: group)
    }

    private func playPrelude(for group: CalloutGroup) async -> Bool {
        guard let audioEngine = audioEngine else { return false }

        var prelude: [Sound] = group.playModeSounds ? [GlyphSound(.enterMode)] : []
        if let prefix = group.prefixCallout?.sounds(for: geo?.location) {
            prelude.append(contentsOf: prefix.soundArray)
        }

        guard !prelude.isEmpty else {
            return true
        }

        guard state == .running else { return false }

        let success = await audioEngine.playAsync(Sounds(prelude))
        if !success {
            GDLogVerbose(.stateMachine, "Prelude failed. Terminating callouts.")
        }
        return success && state == .running
    }

    private func runCallouts(in group: CalloutGroup) async {
        guard state == .running, calloutGroup?.id == group.id else { return }

        while state == .running, calloutGroup?.id == group.id {
            guard let callout = calloutIterator?.next() else {
                notifyCompletion(true)
                await finish(failed: false)
                return
            }

            if let delegate = group.delegate, !delegate.isCalloutWithinRegionToLive(callout) {
                group.delegate?.calloutSkipped(callout)
                continue
            }

            group.delegate?.calloutStarting(callout)
            history?.insert(callout)

            let sounds: Sounds = {
                if let repeatLocation = group.repeatingFromLocation {
                    return callout.sounds(for: repeatLocation, isRepeat: true)
                } else {
                    return callout.sounds(for: geo?.location, automotive: motionActivityContext?.isInVehicle ?? false)
                }
            }()

            CalloutStateMachine.log(callout: callout, context: group.logContext)

            guard let audioEngine = audioEngine else {
                notifyCompletion(false)
                await finish(failed: true)
                return
            }

            let success = await audioEngine.playAsync(sounds)
            group.delegate?.calloutFinished(callout, completed: success)

            guard state == .running else { return }
            guard success else {
                notifyCompletion(false)
                await finish(failed: true)
                return
            }

            if let delay = group.calloutDelay, delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    // MARK: Shutdown

    private func cancelCurrentCallouts(markHushed: Bool, hushSound: Sound?) async {
        if let hushSound {
            pendingHushSound = hushSound
        }

        if state == .off {
            let soundToPlay = pendingHushSound
            pendingHushSound = nil
            await stopDiscreteAudio(play: soundToPlay)
            return
        }

        if state == .stopping {
            hushed = hushed || markHushed
            return
        }

        hushed = markHushed
        state = .stopping
        calloutTask?.cancel()
        calloutTask = nil

        let soundToPlay = pendingHushSound
        pendingHushSound = nil
        await stopDiscreteAudio(play: soundToPlay)
        notifyCompletion(false)

        await finish(failed: true)
    }

    private func finish(failed: Bool) async {
        guard state != .off else { return }

        state = failed ? .failed : .completed

        let id = calloutGroup?.id
        let shouldPlayExit = (!failed) && (!hushed) && (calloutGroup?.playModeSounds ?? false)

        calloutIterator = nil
        calloutTask = nil

        if shouldPlayExit, let audioEngine = audioEngine {
            _ = await audioEngine.playAsync(GlyphSound(.exitMode))
        }

        calloutGroup = nil
        didNotifyCompletion = false
        pendingHushSound = nil
        hushed = false
        state = .off
        await idleSignal.signal()

        if let id = id {
            let delegate = self.delegate
            await MainActor.run {
                delegate?.calloutsDidFinish(id: id)
            }
        }
    }

    private func notifyCompletion(_ success: Bool) {
        guard !didNotifyCompletion, let group = calloutGroup else { return }
        didNotifyCompletion = true
        group.onComplete?(success)
    }

    private func waitUntilIdle() async {
        while state != .off {
            await idleSignal.wait()
        }
    }

    /// Stops any currently playing discrete audio and optionally plays the exit earcon before allowing
    /// the next callout sequence to start. This prevents new callouts from racing ahead while the audio
    /// engine is still tearing down interrupted sounds.
    private func stopDiscreteAudio(play hushSound: Sound?) async {
        guard let audioEngine = audioEngine else { return }

        if let hushSound = hushSound {
            await stopWithHush(hushSound, on: audioEngine)
            return
        }

        await drainDiscreteAudio(on: audioEngine)
    }

    private func stopWithHush(_ hushSound: Sound, on audioEngine: AudioEngineProtocol) async {
        await drainDiscreteAudio(on: audioEngine)
        _ = await audioEngine.playAsync(hushSound)
        await waitForDiscreteAudioSilence(on: audioEngine)
    }

    private func drainDiscreteAudio(on audioEngine: AudioEngineProtocol) async {
        audioEngine.stopDiscrete()
        await waitForDiscreteAudioSilence(on: audioEngine)
    }

    private func waitForDiscreteAudioSilence(on audioEngine: AudioEngineProtocol,
                                             timeout: TimeInterval = 1.0) async {
        if #available(iOS 16.0, *) {
            let clock = ContinuousClock()
            let deadline = clock.now + Duration.seconds(timeout)

            while audioEngine.isDiscreteAudioPlaying && clock.now < deadline {
                try? await Task.sleep(nanoseconds: Self.silencePollInterval)
            }
        } else {
            let end = Date().addingTimeInterval(timeout)

            while audioEngine.isDiscreteAudioPlaying && Date() < end {
                try? await Task.sleep(nanoseconds: Self.silencePollInterval)
            }
        }

        // Give the audio engine a brief moment to finish any remaining stop work even if there
        // were no active players when we entered this helper.
        try? await Task.sleep(nanoseconds: Self.silencePollInterval)
    }
}

private actor IdleSignal {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var pendingSignals = 0

    func wait() async {
        if pendingSignals > 0 {
            pendingSignals -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        guard !waiters.isEmpty else {
            pendingSignals += 1
            return
        }

        let current = waiters
        waiters.removeAll()
        current.forEach { $0.resume() }
    }
}
