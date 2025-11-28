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
    func calloutsDidFinish(id: UUID, finished: Bool)
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
    private let audioPlayback: AudioPlaybackControlling

    private var state: State = .off
    private var hushed = false
    private var pendingHushSound: Sound?
    private var calloutGroup: CalloutGroup?
    private var calloutIterator: IndexingIterator<[CalloutProtocol]>?
    private var calloutTask: Task<Void, Never>?
    private var didNotifyCompletion = false
    private var completionResult: Bool?
    private let idleSignal = IdleSignal()

    init(audioPlayback: AudioPlaybackControlling,
         geo: GeolocationManagerProtocol,
         motionActivityContext motion: MotionActivityProtocol,
         history calloutHistory: CalloutHistory) {
        self.audioPlayback = audioPlayback
        self.geo = geo
        motionActivityContext = motion
        history = calloutHistory
    }

    convenience init(audioEngine engine: AudioEngineProtocol,
                     geo: GeolocationManagerProtocol,
                     motionActivityContext motion: MotionActivityProtocol,
                     history calloutHistory: CalloutHistory) {
        let playbackActor = AudioPlaybackActor(audioEngine: engine)
        self.init(audioPlayback: playbackActor,
                  geo: geo,
                  motionActivityContext: motion,
                  history: calloutHistory)
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
            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE waiting for idle before starting new group \(callouts.id)")
            await waitUntilIdle()
        }

        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE ensuring discrete audio silence before starting group \(callouts.id)")
        await audioPlayback.waitForDiscreteAudioSilence()

        guard state == .off else {
            GDLogVerbose(.stateMachine, "Unable to start callout group. State machine is currently in state: \(state)")
            return
        }

        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE startCallouts group=\(callouts.id) logContext=\(callouts.logContext)")
        calloutGroup = callouts
        calloutIterator = callouts.callouts.makeIterator()
        hushed = false
        didNotifyCompletion = false
        completionResult = nil
        state = .running

        calloutTask = Task { @MainActor in
            await self.execute(callouts)
        }
    }

    private func hushCallouts(playSound: Bool) async {
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE hushCallouts playSound=\(playSound) state=\(state)")
        await cancelCurrentCallouts(markHushed: true, hushSound: playSound ? GlyphSound(.exitMode) : nil)
    }

    private func stopCallouts() async {
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE stopCallouts state=\(state)")
        await cancelCurrentCallouts(markHushed: false, hushSound: nil)
    }

    // MARK: Execution

    private func execute(_ group: CalloutGroup) async {
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE execute group=\(group.id)")
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
        var prelude: [Sound] = group.playModeSounds ? [GlyphSound(.enterMode)] : []
        if let prefix = group.prefixCallout?.sounds(for: geo?.location) {
            prelude.append(contentsOf: prefix.soundArray)
        }

        guard !prelude.isEmpty else {
            return true
        }

        guard state == .running else { return false }

        let success = await audioPlayback.play(Sounds(prelude))
        if !success {
            GDLogVerbose(.stateMachine, "Prelude failed. Terminating callouts.")
        }
        return success && state == .running
    }

    private func runCallouts(in group: CalloutGroup) async {
        guard state == .running, calloutGroup?.id == group.id else { return }

        while state == .running, calloutGroup?.id == group.id {
            guard let callout = calloutIterator?.next() else {
                GDLogVerbose(.stateMachine, "CALL_OUT_TRACE group=\(group.id) completed all callouts")
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

            let success = await audioPlayback.play(sounds)
                GDLogVerbose(.stateMachine, "CALL_OUT_TRACE callout finished group=\(group.id) callout=\(callout.logCategory) success=\(success)")
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
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent markHushed=\(markHushed) hushSound=\(String(describing: hushSound != nil)) state=\(state)")
        if let hushSound {
            pendingHushSound = hushSound
        }

        if state == .off {
            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent no-op state off")
            let soundToPlay = pendingHushSound
            pendingHushSound = nil
            await stopDiscreteAudio(play: soundToPlay)
            return
        }

        if state == .stopping {
            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent already stopping")
            hushed = hushed || markHushed
            return
        }

        hushed = markHushed
        state = .stopping
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelling task for group=\(String(describing: calloutGroup?.id))")
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
        let finishedSuccessfully = completionResult ?? false
        let shouldPlayExit = (!failed) && (!hushed) && (calloutGroup?.playModeSounds ?? false)

        calloutIterator = nil
        calloutTask = nil

        if shouldPlayExit {
            _ = await audioPlayback.play(GlyphSound(.exitMode))
        }

        calloutGroup = nil
        didNotifyCompletion = false
        pendingHushSound = nil
        hushed = false
        completionResult = nil
        state = .off
        await idleSignal.signal()

        if let id = id {
            let delegate = self.delegate
            await MainActor.run {
                GDLogVerbose(.stateMachine, "CALL_OUT_TRACE finish notifying delegate group=\(id) finished=\(finishedSuccessfully)")
                delegate?.calloutsDidFinish(id: id, finished: finishedSuccessfully)
            }
        }
    }

    private func notifyCompletion(_ success: Bool) {
        guard !didNotifyCompletion, let group = calloutGroup else { return }
        didNotifyCompletion = true
        completionResult = success
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE notifyCompletion group=\(group.id) success=\(success)")
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
        await audioPlayback.stopDiscreteAudio(hushSound: hushSound)
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
