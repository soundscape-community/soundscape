import UIKit

class AudioSettingsViewController: UITableViewController {

    // MARK: - Audio Settings Enum
    private enum AudioRow: Int, CaseIterable {
        case mixAudio = 0
    }

    private let audioItems = [
        "Mix Audio" // Placeholder for the Mix Audio setting
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = GDLocalizedString("settings.audio.media_controls")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AudioCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 // Only one section for audio settings
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AudioRow.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AudioCell", for: indexPath)
        
        if let rowType = AudioRow(rawValue: indexPath.row) {
            cell.textLabel?.text = audioItems[indexPath.row]
            
            switch rowType {
            case .mixAudio:
                // Add a switch control to the Mix Audio row
                let switchControl = UISwitch()
                switchControl.isOn = SettingsContext.shared.audioSessionMixesWithOthers
                switchControl.addTarget(self, action: #selector(mixAudioSwitchToggled(_:)), for: .valueChanged)
                cell.accessoryView = switchControl
            }
        }
        
        return cell
    }
    
    // MARK: - Mix Audio Toggle Logic

    @objc private func mixAudioSwitchToggled(_ sender: UISwitch) {
        if sender.isOn {
            // Show confirmation alert if turning on "Mix Audio"
            let alert = UIAlertController(title: GDLocalizedString("general.alert.confirmation_title"),
                                          message: GDLocalizedString("setting.audio.mix_with_others.confirmation"),
                                          preferredStyle: .alert)
            
            let mixAction = UIAlertAction(title: GDLocalizedString("settings.audio.mix_with_others.title"), style: .default) { [weak self] (_) in
                self?.updateMixAudioSetting(true)
            }
            alert.addAction(mixAction)
            alert.preferredAction = mixAction
            
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: { (_) in
                sender.isOn = false
            }))
            
            present(alert, animated: true)
        } else {
            updateMixAudioSetting(false)
        }
    }
    
    private func updateMixAudioSetting(_ newValue: Bool) {
        SettingsContext.shared.audioSessionMixesWithOthers = newValue
        AppContext.shared.audioEngine.mixWithOthers = newValue
        
        GDATelemetry.track("settings.mix_audio",
                           with: ["value": "\(SettingsContext.shared.audioSessionMixesWithOthers)",
                                  "context": "app_settings"])
    }
}

