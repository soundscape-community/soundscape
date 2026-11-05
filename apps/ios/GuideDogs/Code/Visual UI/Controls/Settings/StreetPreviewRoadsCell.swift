//
//  StreetPreviewRoadsCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

class StreetPreviewRoadsCell: UITableViewCell {
    
    var settingSwitch: UISwitch? {
        return accessoryView as? UISwitch
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Initialization code
        settingSwitch?.isOn = SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads
    }

    @IBAction func onSettingValueChanged(_ sender: Any) {
        guard let settingSwitch = self.accessoryView as? UISwitch else {
            return
        }
        
        SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads = settingSwitch.isOn
        
    }

}
