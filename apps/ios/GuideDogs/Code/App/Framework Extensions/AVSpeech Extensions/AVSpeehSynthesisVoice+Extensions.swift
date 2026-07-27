//
//  AVSpeehSynthesisVoice+Extensions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation

extension AVSpeechSynthesisVoice {
    static let knownNoveltyVoiceIdentifiers: Set<String> = [
        "com.apple.speech.synthesis.voice.Albert",
        "com.apple.speech.synthesis.voice.BadNews",
        "com.apple.speech.synthesis.voice.Bahh",
        "com.apple.speech.synthesis.voice.Bells",
        "com.apple.speech.synthesis.voice.Boing",
        "com.apple.speech.synthesis.voice.Bubbles",
        "com.apple.speech.synthesis.voice.Cellos",
        "com.apple.speech.synthesis.voice.Deranged",
        "com.apple.speech.synthesis.voice.GoodNews",
        "com.apple.speech.synthesis.voice.Hysterical",
        "com.apple.speech.synthesis.voice.Organ",
        "com.apple.speech.synthesis.voice.Princess",
        "com.apple.speech.synthesis.voice.Trinoids",
        "com.apple.speech.synthesis.voice.Whisper",
        "com.apple.speech.synthesis.voice.Zarvox"
    ]

    var isNoveltyVoice: Bool {
        if #available(iOS 17.0, *) {
            return voiceTraits.contains(.isNoveltyVoice)
        }

        return Self.knownNoveltyVoiceIdentifiers.contains(identifier)
    }
}
