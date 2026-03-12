//
//  CalloutSettingsCellView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

protocol CalloutSettingsCellViewDelegate: AnyObject {
    func onCalloutSettingChanged(_ type: CalloutSettingCellType)
}

internal enum CalloutSettingCellType {
    case all, poi, beacon, shake
    case transportation
    case intersection
    case safety
}

class CalloutSettingsCellView: UITableViewCell {

    weak var delegate: CalloutSettingsCellViewDelegate?

    var type: CalloutSettingCellType! {
        didSet {
            guard let type = type, let settingSwitch = self.accessoryView as? UISwitch else {
                return
            }

            settingSwitch.isEnabled = type == .all || SettingsContext.shared.automaticCalloutsEnabled

            switch type {
            case .all:
                settingSwitch.isOn = SettingsContext.shared.automaticCalloutsEnabled
            case .poi:
                settingSwitch.isOn = SettingsContext.shared.placeSenseEnabled
            case .beacon:
                settingSwitch.isOn = SettingsContext.shared.destinationSenseEnabled
            case .shake:
                settingSwitch.isOn = SettingsContext.shared.shakeCalloutsEnabled
            case .transportation:
                settingSwitch.isOn = SettingsContext.shared.mobilitySenseEnabled
            case .intersection:
                settingSwitch.isOn = SettingsContext.shared.intersectionSenseEnabled
            case .safety:
                settingSwitch.isOn = SettingsContext.shared.safetySenseEnabled
            }
        }
    }

    @IBAction func onSettingValueChanged(_ sender: Any) {
        guard let type = type, let settingSwitch = self.accessoryView as? UISwitch else {
            return
        }

        defer { delegate?.onCalloutSettingChanged(type) }

        let isOn = settingSwitch.isOn

        let log: ([String]) -> Void = { categories in
            for category in categories {
                GDLogActionInfo("Toggled \(category) callouts to: \(isOn)")
                GDATelemetry.track("settings.autocallouts_\(category)", value: isOn.description)
            }
        }

        switch type {
        case .all:
            SettingsContext.shared.automaticCalloutsEnabled = isOn
            GDATelemetry.track("settings.allow_callouts", value: isOn.description)
        case .poi:
            SettingsContext.shared.placeSenseEnabled = isOn
            SettingsContext.shared.landmarkSenseEnabled = isOn
            SettingsContext.shared.informationSenseEnabled = isOn
            log(["places", "landmarks", "info"])
        case .beacon:
            SettingsContext.shared.destinationSenseEnabled = isOn
            log(["destination"])
        case .shake:
            SettingsContext.shared.shakeCalloutsEnabled = isOn
            GDATelemetry.track("settings.shake_callouts", value: isOn.description)
        case .transportation:
            SettingsContext.shared.mobilitySenseEnabled = isOn
            log(["mobility"])
        case .intersection:
            SettingsContext.shared.intersectionSenseEnabled = isOn
            log(["intersections"])
        case .safety:
            SettingsContext.shared.safetySenseEnabled = isOn
            log(["safety"])
        }
    }
}
