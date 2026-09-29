//
//  SettingStepper.swift
//  Soundscape
//
//  Created by Daniel W. Steinbrook on 8/11/24.
//  Copyright © 2024 Soundscape community. All rights reserved.
//  Copyright (c) Soundscape Community Contributors.
//

import SwiftUI

enum ArrivalDistanceValue {
    static func displayNumber(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func parse(_ text: String, locale: Locale, minValue: Double, maxValue: Double) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let decimalMarks = [separator, ".", ","]
        var normalized = ""
        var fractionDigits: Int?

        for character in trimmed {
            let string = String(character)
            if decimalMarks.contains(string) {
                guard fractionDigits == nil else { return nil }
                normalized.append(separator)
                fractionDigits = 0
            } else {
                guard string.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) else {
                    return nil
                }
                normalized.append(character)
                if let count = fractionDigits {
                    guard count < 2 else { return nil }
                    fractionDigits = count + 1
                }
            }
        }

        guard !normalized.isEmpty, normalized != separator, fractionDigits != 0 else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        guard let number = formatter.number(from: normalized) else { return nil }
        let value = number.doubleValue
        guard value.isFinite, value >= minValue, value <= maxValue else { return nil }
        return value
    }
}

/// A stepper with exact entry for the beacon arrival distance.
struct SettingStepper: View {
    @Binding var value: Double
    private let titleLocalization: String
    private let unitsLocalization: String
    private let stepSize: Double
    private let minValue: Double
    private let maxValue: Double

    @State private var isEditing = false
    @State private var draftValue = ""
    @State private var showsValidationError = false
    @FocusState private var isFieldFocused: Bool

    init(value: Binding<Double>, titleLocalization: String, unitsLocalization: String, stepSize: Double, minValue: Double, maxValue: Double) {
        self._value = value
        self.titleLocalization = titleLocalization
        self.unitsLocalization = unitsLocalization
        self.stepSize = stepSize
        self.minValue = minValue
        self.maxValue = maxValue
    }

    private var locale: Locale { LocalizationContext.currentAppLocale }

    private var formattedValue: String {
        GDLocalizedString(unitsLocalization, ArrivalDistanceValue.displayNumber(value, locale: locale))
    }

    private var unitLabel: String {
        GDLocalizedString(unitsLocalization, "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func increment() {
        value = min(max(value + stepSize, minValue), maxValue)
    }

    private func decrement() {
        value = min(max(value - stepSize, minValue), maxValue)
    }

    private func beginEditing() {
        draftValue = ArrivalDistanceValue.displayNumber(value, locale: locale)
        showsValidationError = false
        isEditing = true
    }

    private func cancelEditing() {
        isFieldFocused = false
        isEditing = false
        showsValidationError = false
    }

    private func commitEditing() {
        guard let parsed = ArrivalDistanceValue.parse(draftValue, locale: locale, minValue: minValue, maxValue: maxValue) else {
            showsValidationError = true
            isFieldFocused = true
            return
        }

        value = parsed
        cancelEditing()
    }

    private var normalControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                GDLocalizedTextView(titleLocalization)
                    .foregroundColor(.primaryForeground)
                    .font(.body)

                Button(action: beginEditing) {
                    HStack(spacing: 6) {
                        Text(formattedValue)
                        Image(systemName: "pencil")
                    }
                    .foregroundColor(.secondaryForeground)
                    .font(.body)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: decrement) {
                Text("-")
                    .font(.title)
                    .frame(width: 44, height: 30)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(value <= minValue)

            Button(action: increment) {
                Text("+")
                    .font(.title)
                    .frame(width: 44, height: 30)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(value >= maxValue)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GDLocalizedString(titleLocalization))
        .accessibilityValue(formattedValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increment()
            case .decrement: decrement()
            @unknown default: break
            }
        }
        .accessibilityAction {
            beginEditing()
        }
    }

    private var editingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GDLocalizedTextView(titleLocalization)
                    .foregroundColor(.primaryForeground)
                    .font(.body)

                Spacer()

                Button(GDLocalizedString("general.alert.cancel"), action: cancelEditing)
                Button(GDLocalizedString("general.alert.done"), action: commitEditing)
            }

            HStack {
                TextField("", text: $draftValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFieldFocused)
                    .accessibilityLabel(GDLocalizedString(titleLocalization))
                    .accessibilityHint(GDLocalizedString("beacon.settings.arrival_distance.edit_hint"))
                    .onAppear { isFieldFocused = true }
                    .onChange(of: draftValue) { _ in showsValidationError = false }

                Text(unitLabel)
                    .foregroundColor(.secondaryForeground)
                    .accessibilityHidden(true)
            }

            if showsValidationError {
                Text(GDLocalizedString("beacon.settings.arrival_distance.invalid"))
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    var body: some View {
        Group {
            if isEditing {
                editingControls
            } else {
                normalControls
            }
        }
        .padding()
        .background(Color.primaryBackground)
    }
}
