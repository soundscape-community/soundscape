//
//  TelemetrySettingsTableViewCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
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
        
        configure()
    }

    func configure() {
        telemetrySwitch?.isOn = GDATelemetry.enabled
        telemetrySwitch?.accessibilityLabel = GDLocalizedString("settings.section.share_usage_data")
    }

    @IBAction func onSettingValueChanged(_ sender: Any) {
        let prevOptedOut = SettingsContext.shared.telemetryOptout
        
        if prevOptedOut {
            GDATelemetry.enabled = true
            configure()
            GDATelemetry.track("settings.telemetry_optout", value: String(false))
        } else {
            let alert = UIAlertController(title: GDLocalizedString("settings.telemetry.optout.alert_title"),
                                          message: GDLocalizedString("settings.telemetry.optout.alert_message"),
                                          preferredStyle: UIAlertController.Style.alert)
            
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: { [weak self] (_) in
                // User canceled, switch back
                self?.telemetrySwitch?.setOn(true, animated: true)
            }))
            
            alert.addAction(UIAlertAction(title: GDLocalizedString("settings.telemetry.optout.action"), style: .destructive, handler: { _ in
                GDATelemetry.enabled = false
            }))
            
            parent?.present(alert, animated: true, completion: nil)
        }
    }

}
