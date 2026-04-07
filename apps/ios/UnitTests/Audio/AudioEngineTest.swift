//
//  AudioEngineTest.swift
//  
//
//  Created by Kai on 10/11/23.
//

import XCTest
@testable import Soundscape
import AVFAudio

class TestAudioEnvironmentSettings: EnvironmentSettingsProvider {
    var envRenderingAlgorithm: AVAudio3DMixingRenderingAlgorithm = .auto
    var envRenderingDistance: Double = 40
    var envRenderingReverbEnable: Bool = false
    var envRenderingReverbPreset: AVAudioUnitReverbPreset = .mediumRoom
    var envRenderingReverbBlend: Float = 0
    var envRenderingReverbLevel: Float = 0
    var envReverbFilterActive: Bool = false
    var envReverbFilterBandwidth: Float = 0
    var envReverbFilterBypass: Bool = true
    var envReverbFilterType: AVAudioUnitEQFilterType = .parametric
    var envReverbFilterFrequency: Float = 0
    var envReverbFilterGain: Float = 0
}

final class TestSound: SynchronouslyGeneratedSound {
    let type: SoundType = .standard
    let layerCount: Int = 1
    let description: String

    private var buffer: AVAudioPCMBuffer?

    init(description: String, frequency: Float = 440) {
        self.description = description

        let sampleRate = 44_100.0
        let frameCount: AVAudioFrameCount = 44_100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let samples = buffer.floatChannelData?[0] {
            for frame in 0 ..< Int(frameCount) {
                let phase = Float(frame) * frequency * 2 * .pi / Float(sampleRate)
                samples[frame] = sin(phase) * 0.1
            }
        }

        self.buffer = buffer
    }

    func generateBuffer(forLayer index: Int) -> AVAudioPCMBuffer? {
        guard index == 0 else {
            return nil
        }

        defer {
            buffer = nil
        }

        return buffer
    }

    func equalizerParams(for layerIndex: Int) -> EQParameters? {
        return nil
    }
}

final class AudioEngineTest: XCTestCase {
    class TestAudioEngineDelegate: AudioEngineDelegate {
        func didFinishPlaying() {
            finish_count += 1
        }
        
        var finish_count = 0
    }
    
    var audioEngine: AudioEngine?
    
    override func tearDown() {
        super.tearDown()
        // Stop and clean up the audio engine to prevent multiple engines running simultaneously
        audioEngine?.stop()
        audioEngine = nil
    }
    
    /// Ensures the initial state is correct
    func testInit() throws {
        audioEngine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: false)
        let eng = audioEngine!
        XCTAssertNil(eng.delegate)
        XCTAssertFalse(eng.isInMonoMode) // currently always true as it is not implemented
        XCTAssertFalse(eng.isDiscreteAudioPlaying)
        XCTAssertFalse(eng.isRecording)
        XCTAssertFalse(eng.mixWithOthers)
    }
    
    func testPlayBad() throws {
        // TODO: this
    }
    
    /// Just playing a single `Sound`
    func testDiscreteAudio2DSimple() throws {
        audioEngine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: false)
        let eng = audioEngine!
        let delegate = TestAudioEngineDelegate()
        eng.delegate = delegate
        let expectation = XCTestExpectation()
        
        XCTAssertEqual(delegate.finish_count, 0)
        XCTAssertFalse(eng.isDiscreteAudioPlaying)
        eng.play(TestSound(description: "testing a sound")) { success in
            XCTAssertTrue(success)
            XCTAssertEqual(delegate.finish_count, 1)
            expectation.fulfill()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 30), .completed)
        XCTAssertEqual(delegate.finish_count, 1)
        XCTAssertFalse(eng.isDiscreteAudioPlaying)
    }
    
    /// Play a series of queued sounds in sequence
    func testDiscreteAudio2DSeveral() throws {
        audioEngine = AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: false)
        let eng = audioEngine!
        let delegate = TestAudioEngineDelegate()
        eng.delegate = delegate
        let expectations = [XCTestExpectation(description: "one"),
                            XCTestExpectation(description: "two"),
                            XCTestExpectation(description: "three")]
        
        XCTAssertEqual(delegate.finish_count, 0)
        XCTAssertFalse(eng.isDiscreteAudioPlaying)
        eng.play(TestSound(description: "one one one", frequency: 440)) { success in
            XCTAssertTrue(success)
            expectations[0].fulfill()
        }
        eng.play(TestSound(description: "two two two", frequency: 550)) { success in
            XCTAssertTrue(success)
            expectations[1].fulfill()
        }
        eng.play(TestSound(description: "three three three", frequency: 660)) { success in
            XCTAssertTrue(success)
            expectations[2].fulfill()
        }
        
        XCTAssertEqual(XCTWaiter.wait(for: expectations, timeout: 30), .completed)
        XCTAssertEqual(delegate.finish_count, 3)
        XCTAssertFalse(eng.isDiscreteAudioPlaying)
    }

}
