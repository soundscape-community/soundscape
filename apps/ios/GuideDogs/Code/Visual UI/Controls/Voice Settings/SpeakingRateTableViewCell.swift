//
//  SpeakingRateTableViewCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

class SpeakingRateTableViewCell: UITableViewCell {
    
    // MARK: Properties
    
    @IBOutlet weak var speakingRateSlider: UISlider!
    // Replace legacy DispatchWorkItem + asyncAfter with structured concurrency Task for cancellation semantics
    fileprivate var previousTask: Task<Void, Never>?
    
    func initialize() {
        // We only want to receive the valueChanged event when the user stops moving the slider.
        speakingRateSlider.isContinuous = false
        
        // Load the speaking rate setting.
        speakingRateSlider.value = SettingsContext.shared.speakingRate
    }
    
    // MARK: Speaking Rate
    
    @IBAction func onSpeakingRateSliderValueChanged() {
        SettingsContext.shared.speakingRate = speakingRateSlider.value
        
        announcementTest()
        
        GDATelemetry.track("settings.voice.rate", with: ["value": String(speakingRateSlider.value), "voice": SettingsContext.shared.voiceId ?? "not_set"])
    }
    
    fileprivate func announcementTest() {
        let test = {
            UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false)
            UIRuntimeProviderRegistry.providers.uiAudioEngine()?.stopDiscrete()
            UIRuntimeProviderRegistry.providers.uiProcessEvent(GenericAnnouncementEvent(GDLocalizedString("voice.voice_rate_test")))
        }
        
        // When VoiceOver is running, we will wait until the current announcement has finished
        if !UIAccessibility.isVoiceOverRunning {
            test()
        } else {
            previousTask?.cancel()
            previousTask = Task { @MainActor [weak self] in
                // Sleep for 1.5s (1500ms) before announcing, mimicking previous asyncAfter delay
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                // Ensure cell still alive (weak self not strictly needed for static calls, but keep parity)
                _ = self
                test()
            }
        }
    }
    
}
