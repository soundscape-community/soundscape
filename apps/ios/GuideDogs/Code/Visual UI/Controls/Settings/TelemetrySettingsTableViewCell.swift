//
//  TelemetrySettingsTableViewCell.swift
//  Openscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

class TelemetrySettingsTableViewCell: UITableViewCell {

    weak var parent: UIViewController?
    
    var telemetrySwitch: UISwitch? {
        return accessoryView as? UISwitch
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Initialization code
        telemetrySwitch?.isOn = !SettingsContext.shared.telemetryOptout
    }

    @IBAction func onSettingValueChanged(_ sender: Any) {
        let prevOptedOut = SettingsContext.shared.telemetryOptout
        
        if prevOptedOut {
            // User was opted out and is turning on telemetry (opting in)
            GDATelemetry.enabled = true
            GDATelemetry.track("settings.telemetry_optout", value: String(false))
        } else {
            GDATelemetry.enabled = false
            // Sentry doesn't support deleting events from a specific user
        }
    }

}
