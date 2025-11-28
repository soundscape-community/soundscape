import Foundation

protocol AudioPlaybackControlling: AnyObject {
    func play(_ sounds: Sounds) async -> Bool
    func play(_ sound: Sound) async -> Bool
    func stopDiscreteAudio(hushSound: Sound?) async
    func waitForDiscreteAudioSilence(timeout: TimeInterval) async
}

extension AudioPlaybackControlling {
    func waitForDiscreteAudioSilence() async {
        await waitForDiscreteAudioSilence(timeout: 1.0)
    }
}

actor AudioPlaybackActor: AudioPlaybackControlling {
    private let audioEngine: AudioEngineProtocol
    private static let silencePollInterval: UInt64 = 20_000_000

    init(audioEngine: AudioEngineProtocol) {
        self.audioEngine = audioEngine
    }

    func play(_ sounds: Sounds) async -> Bool {
        await audioEngine.playAsync(sounds)
    }

    func play(_ sound: Sound) async -> Bool {
        await audioEngine.playAsync(sound)
    }

    func stopDiscreteAudio(hushSound: Sound?) async {
        await MainActor.run {
            if let hushSound {
                audioEngine.stopDiscrete(with: hushSound)
            } else {
                audioEngine.stopDiscrete()
            }
        }

        guard hushSound == nil else { return }

        await waitForDiscreteAudioSilence(timeout: 1.0)
    }

    func waitForDiscreteAudioSilence(timeout: TimeInterval = 1.0) async {
        if #available(iOS 16.0, *) {
            let clock = ContinuousClock()
            let deadline = clock.now + Duration.seconds(timeout)

            while await isDiscreteAudioPlaying(), clock.now < deadline {
                try? await Task.sleep(nanoseconds: Self.silencePollInterval)
            }
        } else {
            let end = Date().addingTimeInterval(timeout)

            while await isDiscreteAudioPlaying(), Date() < end {
                try? await Task.sleep(nanoseconds: Self.silencePollInterval)
            }
        }

        try? await Task.sleep(nanoseconds: Self.silencePollInterval)
    }

    private func isDiscreteAudioPlaying() async -> Bool {
        await MainActor.run {
            audioEngine.isDiscreteAudioPlaying
        }
    }
}
