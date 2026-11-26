//
//  CalloutCoordinator.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

// Legacy callouts, validity rules and delegate effects stay on the same actor as behavior delivery.
@MainActor
final class CalloutCoordinator {
    private let playback: any AudioPlayback
    private let legacy: CalloutContext
    private let delay: @Sendable (TimeInterval) async throws -> Void
    private var pending: [CalloutGroup] = []
    private var group: CalloutGroup?
    private enum Step {
        case prefix, callout(CalloutProtocol), exit(Bool), hush(Bool)
    }

    private enum Phase {
        case idle, advancing, delay(UInt64), finishing
        case playing(Step, PlaybackHandle, (@MainActor () -> [any Sound])?)
    }

    private var phase: Phase = .idle
    private var timer: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var index = 0
    private var interrupted = false
    private var playHushAtEnd = false

    nonisolated init(playback: any AudioPlayback, legacy: CalloutContext,
                     delay: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
                         try await Task.sleep(for: .seconds(seconds))
                     }) {
        self.playback = playback
        self.legacy = legacy
        self.delay = delay
    }

    func enqueue(_ group: CalloutGroup) { enqueue([group], useFirstAction: false) }

    func enqueue(_ groups: [CalloutGroup], useFirstAction: Bool = true) {
        for (index, group) in groups.enumerated() {
            let action = useFirstAction && index > 0 ? .enqueue : group.action
            switch action {
            case .enqueue: pending.append(group)
            case .clear: clear(); pending.append(group)
            case .interruptAndClear:
                clear()
                pending.append(group)
                interruptCurrent(clearPending: false, hush: false)
            }
        }
        startNextIfIdle()
    }

    func interruptCurrent(clearPending: Bool, hush: Bool) {
        if clearPending { clear() }
        if group != nil {
            interrupted = true
            playHushAtEnd = playHushAtEnd || hush
        }

        switch phase {
        case .idle:
            if hush { play(Sounds(GlyphSound(.hush)), step: .hush(false)) }
        case .playing(_, let handle, _):
            handle.stop()
        case .delay, .advancing:
            timer?.cancel()
            timer = nil
            finishGroup(false, allowExit: !hush)
        case .finishing:
            // onComplete may synchronously request an interruption. Finish the transition after it returns.
            break
        }
    }

    private func clear() {
        let skipped = pending
        pending.removeAll()
        skipped.forEach { $0.delegate?.calloutsSkipped(for: $0) }
    }

    private func startNextIfIdle() {
        while case .idle = phase, !pending.isEmpty {
            let next = pending.removeFirst()
            guard next.isValid() else { next.delegate?.calloutsSkipped(for: next); continue }
            group = next
            phase = .advancing
            index = 0
            interrupted = false
            playHushAtEnd = false
            next.onStart?()
            guard isAdvancing(next) else { return }
            next.delegate?.calloutsStarted(for: next)
            guard isAdvancing(next) else { return }
            var prefix: [any Sound] = next.playModeSounds ? [GlyphSound(.enterMode)] : []
            let extra = next.prefixCallout.map(legacy.prefix)
            guard isAdvancing(next) else { return }
            prefix.append(contentsOf: extra?.soundArray ?? [])
            if prefix.isEmpty, extra?.availableTail == nil {
                advanceCallout()
            } else {
                play(Sounds(prefix, availableTail: extra?.availableTail), step: .prefix)
            }
            return
        }
    }

    private func isAdvancing(_ expected: CalloutGroup) -> Bool {
        guard case .advancing = phase else { return false }
        return group === expected && !interrupted
    }

    private func advanceCallout() {
        guard let group else { return }
        phase = .advancing
        while index < group.callouts.count {
            let callout = group.callouts[index]
            index += 1
            let valid = group.delegate?.isCalloutWithinRegionToLive(callout) != false
            guard isAdvancing(group) else { return }
            if !valid {
                group.delegate?.calloutSkipped(callout)
                guard isAdvancing(group) else { return }
                continue
            }
            group.delegate?.calloutStarting(callout)
            guard isAdvancing(group) else { return }
            legacy.record(callout)
            let sounds = legacy.sounds(callout, group)
            guard isAdvancing(group) else { return }
            play(sounds, step: .callout(callout))
            return
        }
        finishGroup(true, allowExit: true)
    }

    private func delayNext(_ seconds: TimeInterval?) {
        guard let seconds, seconds >= 0, seconds.isFinite else { advanceCallout(); return }
        generation &+= 1
        let token = generation
        phase = .delay(token)
        let delay = self.delay
        timer = Task { [weak self] in
            do { try await delay(seconds) } catch { return }
            guard let self, case .delay(let current) = self.phase, current == token else { return }
            self.timer = nil
            self.advanceCallout()
        }
    }

    private func play(_ sounds: Sounds, step: Step) {
        let handle = playback.play(AudioRequest(sounds: sounds.soundArray))
        phase = .playing(step, handle, sounds.availableTail)
        Task { [weak self] in
            let result = await handle.completion()
            self?.playbackCompleted(handle, result: result)
        }
    }

    private func playbackCompleted(_ handle: PlaybackHandle, result: PlaybackResult) {
        guard case .playing(let step, let current, let availableTail) = phase, current == handle else { return }

        switch step {
        case .prefix, .callout:
            let completed = !interrupted && result == .completed
            if completed, let tail = availableTail?(), !tail.isEmpty, !interrupted {
                play(Sounds(tail), step: step)
                return
            }
            phase = .advancing
            guard let group else { return }
            let finished = completed && !interrupted
            if case .callout(let callout) = step {
                group.delegate?.calloutFinished(callout, completed: finished)
                guard self.group === group, case .advancing = phase else { return }
            }
            if finished {
                if case .callout = step { delayNext(group.calloutDelay) }
                else { advanceCallout() }
            } else {
                finishGroup(false, allowExit: interrupted && !playHushAtEnd)
            }
        case .exit(let success):
            if playHushAtEnd {
                play(Sounds(GlyphSound(.hush)), step: .hush(false))
            } else {
                releaseGroup(success && !interrupted && result == .completed)
            }
        case .hush(let success):
            releaseGroup(success && !interrupted)
        }
    }

    private func finishGroup(_ success: Bool, allowExit: Bool) {
        guard let group else { return }
        phase = .finishing
        group.onComplete?(success)
        if playHushAtEnd {
            play(Sounds(GlyphSound(.hush)), step: .hush(success))
        } else if allowExit && group.playModeSounds {
            play(Sounds(GlyphSound(.exitMode)), step: .exit(success))
        } else { releaseGroup(success && !interrupted) }
    }

    private func releaseGroup(_ success: Bool) {
        let completed = group
        group = nil
        phase = .idle
        interrupted = false
        playHushAtEnd = false
        if let completed { completed.delegate?.calloutsCompleted(for: completed, finished: success) }
        startNextIfIdle()
    }
}

struct CalloutContext: Sendable {
    let prefix: @MainActor @Sendable (CalloutProtocol) -> Sounds
    let sounds: @MainActor @Sendable (CalloutProtocol, CalloutGroup) -> Sounds
    let record: @MainActor @Sendable (CalloutProtocol) -> Void
}
