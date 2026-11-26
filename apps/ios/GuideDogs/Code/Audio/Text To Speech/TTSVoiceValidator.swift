//
//  TTSVoiceValidator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import Combine

final class TTSVoiceValidator {
    let identifier: String
    private var source: SpeechPCMSource?

    init(identifier: String) { self.identifier = identifier }

    func validate() -> Future<Bool, Never> {
        Future { [weak self] complete in
            guard let self, let voice = AVSpeechSynthesisVoice(identifier: self.identifier) else {
                complete(.success(false))
                return
            }
            let validation = Validation()
            self.source = IOSSpeechPCMSource(text: voice.name, voiceID: voice.identifier) { result in
                if let valid = validation.receive(result) { complete(.success(valid)) }
            }
            self.source?.start()
        }
    }

    deinit { source?.cancel() }

    // The synth can deliver PCM and end-of-stream from different callback contexts.
    private final class Validation: @unchecked Sendable {
        private let lock = NSLock()
        private var receivedAudio = false
        private var finished = false

        func receive(_ result: Result<AVAudioPCMBuffer?, Error>) -> Bool? {
            lock.withLock {
                guard !finished else { return nil }
                switch result {
                case .success(.some): receivedAudio = true; return nil
                case .success(nil): finished = true; return receivedAudio
                case .failure: finished = true; return false
                }
            }
        }
    }
}
