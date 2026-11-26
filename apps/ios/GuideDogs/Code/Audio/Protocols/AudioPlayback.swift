//
//  AudioPlayback.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

protocol AudioPlayback: Sendable {
    var hasTransientAudio: Bool { get }
    @discardableResult
    func play(_ request: AudioRequest) -> PlaybackHandle
    func stopTransientAudio()
}

extension AudioPlayback {
    @discardableResult
    func play(_ sound: any Sound, heading: AudioRequest.HeadingSource = .presentation, loop: Bool = false) -> PlaybackHandle {
        let transient: Bool
        if case .beacon = sound.content { transient = false } else { transient = !loop }
        return play(AudioRequest(sounds: [sound], loops: loop, heading: heading, transient: transient))
    }
}

struct AudioRequest: Sendable {
    enum HeadingSource: Sendable { case presentation, device, collection }
    let sounds: [any Sound]
    var loops = false
    var heading: HeadingSource = .presentation
    var transient = true
    var initialGain: Float = 1
    var usesEffectVolume = true
}

enum PlaybackResult: Equatable, Sendable {
    case completed, stopped, interrupted, failed(String)
}

enum PlaybackCommand: Sendable {
    case stop, finish, gain(Float), focus(Double?)
    case paused(Bool)
    case fade(to: Float, seconds: Double, stop: Bool)
}

struct PlaybackHandle: Sendable, Equatable {
    let state: PlaybackCompletion
    private let submit: @Sendable (PlaybackCommand) -> Void

    init(state: PlaybackCompletion, submit: @escaping @Sendable (PlaybackCommand) -> Void) {
        self.state = state
        self.submit = submit
    }

    func stop() { state.requestStop(); submit(.stop) }
    func finish() { submit(.finish) }
    func setGain(_ gain: Float) { submit(.gain(gain)) }
    func pause() { submit(.paused(true)) }
    func resume() { submit(.paused(false)) }
    func setFocusBearing(_ bearing: Double?) { submit(.focus(bearing)) }
    func fade(to gain: Float, seconds: Double, stop: Bool = false) {
        submit(.fade(to: gain, seconds: seconds, stop: stop))
    }
    func completion() async -> PlaybackResult { await state.wait() }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.state === rhs.state }
}

// All mutable fields are guarded by lock. Continuations resume outside it.
final class PlaybackCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: PlaybackResult?
    private var waiters: [CheckedContinuation<PlaybackResult, Never>] = []
    private var stop = false

    var stopRequested: Bool { lock.withLock { stop } }
    func requestStop() { lock.withLock { stop = true } }

    func wait() async -> PlaybackResult {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock {
                if result == nil { waiters.append(continuation) }
                return result
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }

    func resolve(_ result: PlaybackResult) {
        let waiters = lock.withLock { () -> [CheckedContinuation<PlaybackResult, Never>] in
            guard self.result == nil else { return [] }
            self.result = result
            let pending = self.waiters
            self.waiters.removeAll()
            return pending
        }
        for waiter in waiters { waiter.resume(returning: result) }
    }
}
