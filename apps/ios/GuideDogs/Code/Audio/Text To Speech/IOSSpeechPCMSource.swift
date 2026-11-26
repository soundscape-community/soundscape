//
//  IOSSpeechPCMSource.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import Foundation

enum AudioPreparationError: Error {
    case asset, format, speech, speechBufferLimit
}

typealias SpeechPCMOutput = @Sendable (Result<AVAudioPCMBuffer?, Error>) -> Void

protocol SpeechPCMSource: AnyObject {
    func start()
    func pause()
    func resume()
    func cancel()
}

final class IOSSpeechPCMSource: SpeechPCMSource, Sendable {
    private let worker: Worker

    init(text: String, voiceID: String?, output: @escaping SpeechPCMOutput) {
        worker = Worker(text: text, voiceID: voiceID, output: output)
    }

    func start() { DispatchQueue.main.async { self.worker.start() } }
    func pause() { DispatchQueue.main.async { self.worker.pause() } }
    func resume() { DispatchQueue.main.async { self.worker.resume() } }
    func cancel() { DispatchQueue.main.async { self.worker.cancel() } }

    @MainActor
    private final class Worker: NSObject, AVSpeechSynthesizerDelegate {
        private let text: String
        private let voiceID: String?
        private let output: SpeechPCMOutput
        private var synth: AVSpeechSynthesizer?

        nonisolated init(text: String, voiceID: String?, output: @escaping SpeechPCMOutput) {
            self.text = text
            self.voiceID = voiceID
            self.output = output
        }

        func start() {
            let locale = LocalizationContext.currentAppLocale
            let formatted = PostalAbbreviations.format(LanguageFormatter.expandCodedDirection(for: text), locale: locale)
            let utterance = AVSpeechUtterance(string: formatted.replacingOccurrences(of: "_", with: " "))
            utterance.voice = voiceID.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            utterance.rate = SettingsContext.shared.speakingRate
            let synth = AVSpeechSynthesizer()
            self.synth = synth
            synth.delegate = self
            let receive: @Sendable (AVAudioBuffer) -> Void = { [output] buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { output(.failure(AudioPreparationError.format)); return }
                guard pcm.frameLength > 0 else { output(.success(nil)); return }
                output(Result { try Self.convert(pcm) })
            }
            synth.write(utterance, toBufferCallback: receive)
        }

        private nonisolated static func convert(_ pcm: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: pcm.format.sampleRate,
                                             channels: pcm.format.channelCount, interleaved: false),
                  let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: pcm.frameLength),
                  let converter = AVAudioConverter(from: pcm.format, to: format) else { throw AudioPreparationError.format }
            try converter.convert(to: converted, from: pcm)
            return converted
        }

        func pause() { synth?.pauseSpeaking(at: .immediate) }
        func resume() { synth?.continueSpeaking() }
        func cancel() { synth?.stopSpeaking(at: .immediate) }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            output(.success(nil))
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            output(.failure(AudioPreparationError.speech))
        }
    }
}
