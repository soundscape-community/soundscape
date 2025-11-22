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

@MainActor
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
        eng.play(TTSSound("testing a sound")) { success in
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
        eng.play(TTSSound("one one one")) { success in
            XCTAssertTrue(success)
            XCTAssertEqual(delegate.finish_count, 1)
            expectations[0].fulfill()
        }
        eng.play(TTSSound("two two two")) { success in
            XCTAssertTrue(success)
            XCTAssertEqual(delegate.finish_count, 2)
            expectations[1].fulfill()
        }
        eng.play(TTSSound("three three three")) { success in
            XCTAssertTrue(success)
            XCTAssertEqual(delegate.finish_count, 3)
            expectations[2].fulfill()
        }
        
        XCTAssertEqual(XCTWaiter.wait(for: expectations, timeout: 30, enforceOrder: true), .completed)
        XCTAssertEqual(delegate.finish_count, 3)
        XCTAssertFalse(eng.isDiscreteAudioPlaying)
    }

}
