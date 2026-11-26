//
//  VolumeControls.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine

struct VolumeControls: View {
    let beaconDemo = BeaconDemoHelper()
    
    @State private var ttsTimer: AnyCancellable?
    @State private var otherTimer: AnyCancellable?
    @State private var demo: PlaybackHandle?
    
    var body: some View {
        ZStack {
            Color.quaternaryBackground.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    TableHeaderCell(text: GDLocalizedString("beacon.generic_name"))
                        .accessibility(hidden: true)
                    VolumeControlSlider(current: SettingsContext.shared.beaconVolume) { newValue in
                        SettingsContext.shared.beaconVolume = newValue
                        beaconDemo.play()
                    }
                    .accessibility(label: GDLocalizedTextView("beacon.generic_name"))
                    
                    TableHeaderCell(text: GDLocalizedString("settings.general.voice"))
                        .accessibility(hidden: true)
                    VolumeControlSlider(current: SettingsContext.shared.ttsVolume) { newValue in
                        SettingsContext.shared.ttsVolume = newValue
                        demoTTS()
                    }
                    .accessibility(label: GDLocalizedTextView("settings.general.voice"))
                    
                    TableHeaderCell(text: GDLocalizedString("settings.volume.other"))
                        .accessibility(hidden: true)
                    VolumeControlSlider(current: SettingsContext.shared.otherVolume) { newValue in
                        SettingsContext.shared.otherVolume = newValue
                        demoOther()
                    }
                    .accessibility(label: GDLocalizedTextView("settings.volume.other"))
                }
            }
        }
        .navigationTitle(GDLocalizedTextView("general.volume"))
        .onAppear {
            beaconDemo.prepare()
        }
        .onDisappear {
            ttsTimer?.cancel()
            ttsTimer = nil
            
            otherTimer?.cancel()
            otherTimer = nil
            
            demo?.stop()
            demo = nil
            beaconDemo.restoreState()

        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            beaconDemo.prepare()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            beaconDemo.restoreState()
        }
    }
    
    private func demoTTS() {
        ttsTimer?.cancel()
        if UIAccessibility.isVoiceOverRunning {
            ttsTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect().first().sink { _ in
                playDemo(TTSSound(GDLocalizedString("voice.voice_rate_test")))
                ttsTimer = nil
            }
        } else { playDemo(TTSSound(GDLocalizedString("voice.voice_rate_test"))) }
    }

    private func demoOther() {
        otherTimer?.cancel()
        if UIAccessibility.isVoiceOverRunning {
            otherTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect().first().sink { _ in
                playDemo(GlyphSound(.connectionSuccess))
                otherTimer = nil
            }
        } else { playDemo(GlyphSound(.connectionSuccess)) }
    }

    private func playDemo(_ sound: any Sound) {
        demo?.stop()
        demo = AppContext.shared.audioEngine.play(sound)
    }

}

struct VolumeControls_Previews: PreviewProvider {
    static var previews: some View {
        VolumeControls()
    }
}
