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
    private var current: CalloutProtocol?
    private var handle: PlaybackHandle?
    private var idleHush: PlaybackHandle?
    private var timer: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var index = 0
    private var reported = false
    private var ending = false
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
        guard group != nil else {
            if hush {
                idleHush?.stop()
                let handle = playback.play(AudioRequest(sounds: [GlyphSound(.hush)]))
                idleHush = handle
                Task { [weak self] in
                    _ = await handle.completion()
                    guard let self, self.idleHush == handle else { return }
                    self.idleHush = nil
                    self.startNextIfIdle()
                }
            } else {
                idleHush?.stop()
            }
            return
        }
        interrupted = true
        playHushAtEnd = playHushAtEnd || hush
        timer?.cancel()
        timer = nil
        generation &+= 1
        if let handle { handle.stop() }
        else { finishGroup(false, allowExit: !hush) }
    }

    private func clear() {
        let skipped = pending
        pending.removeAll()
        skipped.forEach { $0.delegate?.calloutsSkipped(for: $0) }
    }

    private func startNextIfIdle() {
        guard group == nil, idleHush == nil else { return }
        while !pending.isEmpty {
            let next = pending.removeFirst()
            guard next.isValid() else { next.delegate?.calloutsSkipped(for: next); continue }
            group = next
            index = 0
            reported = false
            ending = false
            interrupted = false
            playHushAtEnd = false
            next.onStart?()
            guard group === next, !interrupted else { return }
            if next.stopSoundsBeforePlaying { playback.stopTransientAudio() }
            next.delegate?.calloutsStarted(for: next)
            guard group === next, !interrupted else { return }
            var prefix: [any Sound] = next.playModeSounds ? [GlyphSound(.enterMode)] : []
            let extra = next.prefixCallout.map(legacy.prefix)
            prefix.append(contentsOf: extra?.soundArray ?? [])
            if prefix.isEmpty { advanceCallout() }
            else {
                play(Sounds(prefix, availableTail: extra?.availableTail)) { result in
                    if result == .completed { self.advanceCallout() }
                    else { self.finishGroup(false, allowExit: self.interrupted && !self.playHushAtEnd) }
                }
            }
            return
        }
    }

    private func advanceCallout() {
        guard let group else { return }
        while index < group.callouts.count {
            let callout = group.callouts[index]
            index += 1
            if group.delegate?.isCalloutWithinRegionToLive(callout) == false {
                group.delegate?.calloutSkipped(callout)
                continue
            }
            current = callout
            group.delegate?.calloutStarting(callout)
            guard self.group === group, !interrupted else { return }
            legacy.record(callout)
            let sounds = legacy.sounds(callout, group)
            play(sounds) { result in
                self.current = nil
                group.delegate?.calloutFinished(callout, completed: result == .completed)
                if result == .completed { self.delayNext(group.calloutDelay) }
                else { self.finishGroup(false, allowExit: self.interrupted && !self.playHushAtEnd) }
            }
            return
        }
        finishGroup(true, allowExit: true)
    }

    private func delayNext(_ seconds: TimeInterval?) {
        guard let seconds, seconds >= 0, seconds.isFinite else { advanceCallout(); return }
        generation &+= 1
        let token = generation
        let delay = self.delay
        timer = Task { [weak self] in
            do { try await delay(seconds) } catch { return }
            guard let self, self.generation == token else { return }
            self.timer = nil
            self.advanceCallout()
        }
    }

    private func play(_ sounds: Sounds, then done: @escaping (PlaybackResult) -> Void) {
        let handle = playback.play(AudioRequest(sounds: sounds.soundArray))
        self.handle = handle
        Task { [weak self] in
            let result = await handle.completion()
            guard let self, self.handle == handle else { return }
            self.handle = nil
            if self.interrupted && !self.ending { done(.stopped); return }
            if result == .completed, let tail = sounds.availableTail?(), !tail.isEmpty {
                self.play(Sounds(tail), then: done)
            } else { done(result) }
        }
    }

    private func finishGroup(_ success: Bool, allowExit: Bool) {
        guard let group, !ending else { return }
        ending = true
        if !reported {
            reported = true
            group.onComplete?(success)
        }
        if playHushAtEnd {
            play(Sounds(GlyphSound(.hush))) { _ in self.releaseGroup(success && !self.interrupted) }
        } else if allowExit && group.playModeSounds {
            play(Sounds(GlyphSound(.exitMode))) { _ in
                if self.playHushAtEnd {
                    self.play(Sounds(GlyphSound(.hush))) { _ in self.releaseGroup(false) }
                } else { self.releaseGroup(success && !self.interrupted) }
            }
        } else { releaseGroup(success) }
    }

    private func releaseGroup(_ success: Bool) {
        guard let group else { return }
        self.group = nil
        current = nil
        group.delegate?.calloutsCompleted(for: group, finished: success)
        startNextIfIdle()
    }
}

struct CalloutContext: Sendable {
    let prefix: @MainActor @Sendable (CalloutProtocol) -> Sounds
    let sounds: @MainActor @Sendable (CalloutProtocol, CalloutGroup) -> Sounds
    let record: @MainActor @Sendable (CalloutProtocol) -> Void
}
