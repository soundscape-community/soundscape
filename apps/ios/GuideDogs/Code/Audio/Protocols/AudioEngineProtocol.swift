//
//  AudioEngineProtocol.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import AVFoundation
import CoreLocation
import Foundation

protocol AudioEngineDelegate: AnyObject {
    /// Fires when the underlying AVAudioPlayerNode triggers the .dataPlayedBack callback signalling
    /// that the audio that was being played has finished playing to the speakers.
    func didFinishPlaying()
}

@MainActor
protocol AudioEngineProtocol: AnyObject {
    
    typealias CompletionCallback = (Bool) -> Void
    
    var session: AVAudioSession { get }
    var outputType: String { get }
    
    var delegate: AudioEngineDelegate? { get set }
    
    var isRecording: Bool { get }
    var isDiscreteAudioPlaying: Bool { get }
    var isInMonoMode: Bool { get }
    var mixWithOthers: Bool { get set }
    
    static var recordingDirectory: URL? { get }
    
    func start(isRestarting: Bool, activateAudioSession: Bool)
    func stop()
    
    func play<T: DynamicSound>(_ sound: T, heading: Heading?) -> AudioPlayerIdentifier?
    func play(_ sound: SynchronouslyGeneratedSound) -> AudioPlayerIdentifier?
    func play(looped: SynchronouslyGeneratedSound) -> AudioPlayerIdentifier?
    func play(_ sound: Sound, completion callback: CompletionCallback?)
    func play(_ sounds: Sounds, completion callback: CompletionCallback?)
    
    func finish(dynamicPlayerId: AudioPlayerIdentifier)
    func stop(_ id: AudioPlayerIdentifier)
    func stopDiscrete(with: Sound?)
    
    func updateUserLocation(_ location: CLLocation)
    
    func startRecording()
    func stopRecording()
    
    func enableSpeakerMode(_ handler: ((AVAudioSession.PortOverride) -> Void)?)
    func disableSpeakerMode(_ handler: ((AVAudioSession.PortOverride) -> Void)?)
}

private final class PlaybackContinuationToken<T> {
    private var continuation: CheckedContinuation<T, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(returning: value)
    }
}

extension AudioEngineProtocol {
    func start(isRestarting: Bool = false, activateAudioSession: Bool = true) {
        start(isRestarting: isRestarting, activateAudioSession: activateAudioSession)
    }
    
    func play<T: DynamicSound>(_ sound: T) -> AudioPlayerIdentifier? {
        play(sound, heading: nil)
    }
    
    func play(_ sound: Sound) {
        play(sound, completion: nil)
    }
    
    func play(_ sounds: Sounds) {
        play(sounds, completion: nil)
    }
    
    func stopDiscrete(with: Sound? = nil) {
        stopDiscrete(with: with)
    }

    func playAsync(_ sound: Sound) async -> Bool {
        await awaitPlayback { completion in
            play(sound, completion: completion)
        }
    }

    func playAsync(_ sounds: Sounds) async -> Bool {
        await awaitPlayback { completion in
            play(sounds, completion: completion)
        }
    }

    private func awaitPlayback(_ body: (@escaping (Bool) -> Void) -> Void) async -> Bool {
        var token: PlaybackContinuationToken<Bool>?

        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let newToken = PlaybackContinuationToken(continuation)
                token = newToken
                body { success in
                    newToken.resume(success)
                }
            }
        } onCancel: {
            token?.resume(false)
        }

        token = nil
        return result
    }
}
