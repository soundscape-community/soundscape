import UIKit

class GeneralSettingsViewController: UITableViewController {

    private enum GeneralRow: Int, CaseIterable {
        case languageAndRegion = 0
        case voice
        case beaconSettings
        case volumeSettings
        case manageDevices
        case siriShortcuts
    }

    // Row labels for each setting option in the General section
    private let generalItems = [
        "Language & Region",
        "Voice",
        "Beacon Settings",
        "Volume Settings",
        "Manage Devices",
        "Siri Shortcuts"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = GDLocalizedString("settings.section.general")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GeneralCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 // Only one section for general items
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return GeneralRow.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GeneralCell", for: indexPath)
        
        if let rowType = GeneralRow(rawValue: indexPath.row) {
            cell.textLabel?.text = generalItems[indexPath.row]
            
            // Customize cells if needed (e.g., add switches or controls)
            switch rowType {
            case .languageAndRegion, .voice, .beaconSettings, .manageDevices, .siriShortcuts:
                cell.accessoryType = .disclosureIndicator // These would open additional settings screens
            case .volumeSettings:
                // Example: Adding a slider for volume control directly in the cell
                let volumeSlider = UISlider()
                volumeSlider.value = 0.5 // Default value; adjust based on saved settings
                volumeSlider.addTarget(self, action: #selector(volumeSliderChanged(_:)), for: .valueChanged)
                cell.accessoryView = volumeSlider
            }
        }
        
        return cell
    }

    // Handle row selection
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let rowType = GeneralRow(rawValue: indexPath.row) {
            switch rowType {
            case .languageAndRegion:
                openLanguageAndRegionSettings()
            case .voice:
                openVoiceSettings()
            case .beaconSettings:
                openBeaconSettings()
            case .manageDevices:
                openManageDevicesSettings()
            case .siriShortcuts:
                openSiriShortcutsSettings()
            case .volumeSettings:
                // Volume setting already has a slider; no further action required here
                break
            }
        }
    }

    // Helper methods for each setting action
    private func openLanguageAndRegionSettings() {
        // Logic to load or modify Language & Region settings.
        showActionAlert(title: "Language & Region", message: "This opens Language & Region settings.")
    }

    private func openVoiceSettings() {
        // Logic to load or modify Voice settings.
        showActionAlert(title: "Voice", message: "This opens Voice settings.")
    }

    private func openBeaconSettings() {
        // Logic to load or modify Beacon settings.
        showActionAlert(title: "Beacon Settings", message: "This opens Beacon Settings.")
    }

    private func openManageDevicesSettings() {
        // Logic to load or modify Manage Devices settings.
        showActionAlert(title: "Manage Devices", message: "This opens Manage Devices settings.")
    }

    private func openSiriShortcutsSettings() {
        // Logic to load or modify Siri Shortcuts settings.
        showActionAlert(title: "Siri Shortcuts", message: "This opens Siri Shortcuts settings.")
    }

    // Volume slider action
    @objc private func volumeSliderChanged(_ sender: UISlider) {
        let volume = sender.value
        // Logic to save or update volume settings in SettingsContext or similar
        print("Volume changed to: \(volume)")
    }

    // Helper method to show action alerts as placeholders
    private func showActionAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}

