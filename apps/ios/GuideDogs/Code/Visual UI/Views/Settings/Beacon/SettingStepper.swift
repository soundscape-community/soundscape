//
//  SettingStepper.swift
//  Soundscape
//
//  Created by Daniel W. Steinbrook on 8/11/24.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import SwiftUI
import SSLanguage

/// Defines a stepper (increment/decrement buttons) that can be used for settings like Enter Vicinity Distance.
/// Takes a step size, min, max, and shared localization key for printing the value with units.
/// `unitsLocalization` should be a shared `SSLanguage` key like "distance.format.meters".
struct SettingStepper: View {
    @Binding var value: Double
    private let unitsLocalization: String
    private let stepSize: Double
    private let minValue: Double
    private let maxValue: Double
    
    init(value: Binding<Double>, unitsLocalization: String, stepSize: Double, minValue: Double, maxValue: Double) {
        self._value = value
        self.unitsLocalization = unitsLocalization
        self.stepSize = stepSize
        self.minValue = minValue
        self.maxValue = maxValue
    }
    
    // Increment and Decrement actions
    private func increment() {
        let newValue = value + stepSize
        value = min(max(newValue, minValue), maxValue)
    }
    
    private func decrement() {
        let newValue = value - stepSize
        value = min(max(newValue, minValue), maxValue)
    }

    private var formattedValue: String {
        let localizedValue = String(format: "%.0f", value)
        return LanguageLocalizer.localizedString(
            unitsLocalization,
            arguments: [localizedValue],
            locale: LocalizationContext.currentAppLocale,
            normalizeArguments: true
        )
    }
    
    var body: some View {
        VStack {
            /// We don't use the native `Stepper` because the increment/decrement
            /// controls can't be styled, and the defaults are low contrast.
            HStack {
                // truncate `value` at the decimal point
                Text(formattedValue)
                    .foregroundColor(.primaryForeground)
                    .font(.body)
                    .lineLimit(nil)

                Spacer()

                Button(action: decrement) {
                    Text("-")
                        .font(.title)
                        .frame(width: 44, height: 30)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .accessibilityLabel(Text("Decrease"))
                .disabled(value <= self.minValue)

                Button(action: increment) {
                    Text("+")
                        .font(.title)
                        .frame(width: 44, height: 30)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .accessibilityLabel(Text("Increase"))
                .disabled(value >= self.maxValue)
            }
            .padding()
            .background(Color.primaryBackground)
            .accessibilityElement(children: .ignore)
            .accessibilityValue(formattedValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    increment()
                case .decrement:
                    decrement()
                @unknown default:
                    break
                }
            }
        }
    }
}
