//
//  CalloutCoordinator.swift
//  Soundscape
//
//  Created to migrate the legacy callout queue/delegate chain toward an async-friendly coordinator.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

@MainActor
final class CalloutCoordinator {

    private final class GroupCompletionToken {
        private var continuation: CheckedContinuation<Bool, Never>?
        private var didResume = false

        init(continuation: CheckedContinuation<Bool, Never>) {
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

    private struct QueuedGroup {
        let group: CalloutGroup
        let completionToken: GroupCompletionToken?
    }

    private enum PlaybackState: CustomStringConvertible {
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

    private var calloutQueue = Queue<QueuedGroup>()
    private var currentQueuedGroup: QueuedGroup?

    private let audioPlayback: AudioPlaybackControlling
    private weak var geo: GeolocationManagerProtocol?
    private weak var motionActivityContext: MotionActivityProtocol?
    private weak var history: CalloutHistory?

    private var playbackState: PlaybackState = .off
    private var hushed = false
    private var pendingHushSound: Sound?
    private var calloutIterator: IndexingIterator<[CalloutProtocol]>?
    private var playbackTask: Task<Void, Never>?
    private var didNotifyCompletion = false
    private var completionResult: Bool?
    private let idleSignal = IdleSignal()

    init(audioPlayback: AudioPlaybackControlling,
         geo: GeolocationManagerProtocol,
         motionActivityContext: MotionActivityProtocol,
         history: CalloutHistory) {
        self.audioPlayback = audioPlayback
        self.geo = geo
        self.motionActivityContext = motionActivityContext
        self.history = history
    }

    convenience init(audioEngine: AudioEngineProtocol,
                     geo: GeolocationManagerProtocol,
                     motionActivityContext: MotionActivityProtocol,
                     history: CalloutHistory) {
        let playbackActor = AudioPlaybackActor(audioEngine: audioEngine)
        self.init(audioPlayback: playbackActor,
                  geo: geo,
                  motionActivityContext: motionActivityContext,
                  history: history)
    }

    var hasPendingCallouts: Bool {
        !calloutQueue.isEmpty
    }

    var hasActiveCallouts: Bool {
        currentQueuedGroup != nil
    }

    func enqueue(_ callouts: CalloutGroup, continuation: CheckedContinuation<Bool, Never>? = nil) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator enqueue group=\(callouts.id) action=\(callouts.action) hushOnInterrupt=\(callouts.playHushOnInterrupt)")

        let token = continuation.map { GroupCompletionToken(continuation: $0) }
        calloutQueue.enqueue(QueuedGroup(group: callouts, completionToken: token))

        tryStartCallouts()
    }

    func playCallouts(_ callouts: CalloutGroup) async -> Bool {
        await withCheckedContinuation { continuation in
            enqueue(callouts, continuation: continuation)
        }
    }

    func clearPending() {
        clearQueue()
    }

    func interruptCurrent(clearQueue shouldClear: Bool, playHush: Bool) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator interrupt playHush=\(playHush) clearQueue=\(shouldClear)")

        let hushSound = playHush ? GlyphSound(.exitMode) : nil
        Task { @MainActor in
            await self.cancelCurrentCallouts(markHushed: playHush, hushSound: hushSound)
        }

        if shouldClear {
            clearQueue()
        }
    }

    // MARK: - Private helpers

    private func tryStartCallouts() {
        guard currentQueuedGroup == nil else {
            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator tryStartCallouts skipped playback busy current=\(String(describing: currentQueuedGroup?.group.id))")
            return
        }

        guard let nextQueued = nextValidQueuedGroup() else {
            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator tryStartCallouts found no valid groups")
            return
        }

        currentQueuedGroup = nextQueued

        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator starting callouts group=\(nextQueued.group.id) logContext=\(nextQueued.group.logContext)")
        startCallouts(nextQueued.group)
    }

    private func startCallouts(_ group: CalloutGroup) {
        playbackTask = Task { @MainActor [weak self] in
            await self?.beginPlayback(for: group)
        }
    }

    private func beginPlayback(for group: CalloutGroup) async {
        if playbackState != .off {
            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE waiting for idle before starting new group \(group.id)")
            await waitUntilIdle()
        }

        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE ensuring discrete audio silence before starting group \(group.id)")
        await audioPlayback.waitForDiscreteAudioSilence()

        guard playbackState == .off else {
            GDLogVerbose(.stateMachine, "Unable to start callout group. Coordinator playback is currently in state: \(playbackState)")
            return
        }

        guard currentQueuedGroup?.group.id == group.id else {
            return
        }

        calloutIterator = group.callouts.makeIterator()
        hushed = false
        didNotifyCompletion = false
        completionResult = nil
        playbackState = .running

        await execute(group)
    }

    private func execute(_ group: CalloutGroup) async {
        guard playbackState == .running, currentQueuedGroup?.group.id == group.id else { return }

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

        guard playbackState == .running else { return false }

        let success = await audioPlayback.play(Sounds(prelude))
        if !success {
            GDLogVerbose(.stateMachine, "Prelude failed. Terminating callouts.")
        }
        return success && playbackState == .running
    }

    private func runCallouts(in group: CalloutGroup) async {
        guard playbackState == .running, currentQueuedGroup?.group.id == group.id else { return }

        while playbackState == .running, currentQueuedGroup?.group.id == group.id {
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

            log(callout: callout, context: group.logContext)

            let success = await audioPlayback.play(sounds)
            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE callout finished group=\(group.id) callout=\(callout.logCategory) success=\(success)")
            group.delegate?.calloutFinished(callout, completed: success)

            guard playbackState == .running else { return }
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

    private func cancelCurrentCallouts(markHushed: Bool, hushSound: Sound?) async {
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent markHushed=\(markHushed) hushSound=\(String(describing: hushSound != nil)) state=\(playbackState)")
        if let hushSound {
            pendingHushSound = hushSound
        }

        if playbackState == .off {
            guard currentQueuedGroup != nil else {
                GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent no-op state off")
                let soundToPlay = pendingHushSound
                pendingHushSound = nil
                await stopDiscreteAudio(play: soundToPlay)
                return
            }

            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent completing staged group")
            hushed = markHushed

            playbackTask?.cancel()
            playbackTask = nil

            let soundToPlay = pendingHushSound
            pendingHushSound = nil
            await stopDiscreteAudio(play: soundToPlay)

            notifyCompletion(false)

            let group = currentQueuedGroup?.group
            let id = group?.id
            currentQueuedGroup = nil
            didNotifyCompletion = false
            completionResult = nil
            hushed = false

            if let group, let id {
                handlePlaybackFinished(group: group, id: id, finished: false)
            }

            return
        }

        if playbackState == .stopping {
            GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelCurrent already stopping")
            hushed = hushed || markHushed
            return
        }

        hushed = markHushed
        playbackState = .stopping
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE cancelling task for group=\(String(describing: currentQueuedGroup?.group.id))")
        playbackTask?.cancel()
        playbackTask = nil

        let soundToPlay = pendingHushSound
        pendingHushSound = nil
        await stopDiscreteAudio(play: soundToPlay)
        notifyCompletion(false)

        await finish(failed: true)
    }

    private func finish(failed: Bool) async {
        guard playbackState != .off else { return }

        playbackState = failed ? .failed : .completed

        let group = currentQueuedGroup?.group
        let id = group?.id
        let finishedSuccessfully = completionResult ?? false
        let shouldPlayExit = (!failed) && (!hushed) && (group?.playModeSounds ?? false)

        calloutIterator = nil
        playbackTask = nil

        if shouldPlayExit {
            _ = await audioPlayback.play(GlyphSound(.exitMode))
        }

        currentQueuedGroup = nil
        didNotifyCompletion = false
        pendingHushSound = nil
        hushed = false
        completionResult = nil
        playbackState = .off
        await idleSignal.signal()

        if let id {
            handlePlaybackFinished(group: group, id: id, finished: finishedSuccessfully)
        }
    }

    private func handlePlaybackFinished(group: CalloutGroup?, id: UUID, finished: Bool) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator calloutsDidFinish id=\(id) finished=\(finished)")
        if let group {
            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator notifying delegate completion group=\(id) finished=\(finished)")
            group.delegate?.calloutsCompleted(for: group, finished: finished)
        }

        if !calloutQueue.isEmpty {
            tryStartCallouts()
        }
    }

    private func nextValidQueuedGroup() -> QueuedGroup? {
        while !calloutQueue.isEmpty {
            guard let queued = calloutQueue.dequeue() else {
                continue
            }

            guard queued.group.isValid() else {
                GDLogEventProcessorInfo("Discarding invalid callout group with id: \(queued.group.id), context: \(queued.group.logContext)")
                skip(queued)
                continue
            }

            return queued
        }

        return nil
    }

    private func clearQueue() {
        while !calloutQueue.isEmpty {
            guard let queued = calloutQueue.dequeue() else {
                continue
            }

            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator clearing pending group=\(queued.group.id)")
            skip(queued)
        }
    }

    private func notifyCompletion(_ success: Bool) {
        guard !didNotifyCompletion, let queued = currentQueuedGroup else { return }
        didNotifyCompletion = true
        completionResult = success
        GDLogVerbose(.stateMachine, "CALL_OUT_TRACE notifyCompletion group=\(queued.group.id) success=\(success)")
        queued.group.onComplete?(success)
        queued.completionToken?.resumeOnce(success)
    }

    private func skip(_ queued: QueuedGroup) {
        queued.group.delegate?.calloutsSkipped(for: queued.group)
        queued.group.onSkip?()
        queued.completionToken?.resumeOnce(false)
    }

    private func waitUntilIdle() async {
        while playbackState != .off {
            await idleSignal.wait()
        }
    }

    private func stopDiscreteAudio(play hushSound: Sound?) async {
        await audioPlayback.stopDiscreteAudio(hushSound: hushSound)
    }

    private func log(callout: CalloutProtocol, context: String?) {
        var properties = ["type": callout.logCategory,
                          "activity": AppContext.shared.motionActivityContext.currentActivity.rawValue,
                          "audio.output": AppContext.shared.audioEngine.outputType]

        if let context {
            properties["context"] = context
        }

        GDATelemetry.track("callout", with: properties)
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
}
