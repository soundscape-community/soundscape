//
//  BeaconAngleSlider.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

struct BeaconAngleSlider: View {
    @State private var largeStep: Bool = UIAccessibility.isVoiceOverRunning
    @State var angle: Double
    
    let onUpdate: (Double) -> Void
    
    init(current: Double, onUpdate: @escaping (Double) -> Void) {
        _angle = State(initialValue: current)
        self.onUpdate = onUpdate
    }
    
    var step: Double {
        largeStep ? 5.0 : 1.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                GDLocalizedTextView("beacon.settings.ringing_angle")
                    .font(.subheadline)
                    .foregroundColor(.primaryForeground)
                Spacer()
                Text("\(Int(angle))°")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.secondaryForeground)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Slider(value: $angle, in: 5...20, step: step) { isEditing in
                if !isEditing {
                    onUpdate(angle)
                }
            }
            .accentColor(.secondaryForeground)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityLabel(GDLocalizedTextView("beacon.settings.ringing_angle"))
            .accessibilityValue(Text("\(Int(angle)) degrees"))
        }
        .background(Color.primaryBackground)
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
            largeStep = UIAccessibility.isVoiceOverRunning
        }
    }
}
