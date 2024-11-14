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
                // Example: Adding a slider for volume control
                let volumeSlider = UISlider()
                volumeSlider.value = 0.5 // Default value; adjust based on saved settings
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
                // Navigate to Language & Region settings screen
                print("Open Language & Region settings")
            case .voice:
                // Navigate to Voice settings screen
                print("Open Voice settings")
            case .beaconSettings:
                // Navigate to Beacon Settings screen
                print("Open Beacon Settings")
            case .manageDevices:
                // Navigate to Manage Devices settings screen
                print("Open Manage Devices settings")
            case .siriShortcuts:
                // Navigate to Siri Shortcuts settings screen
                print("Open Siri Shortcuts settings")
            case .volumeSettings:
                // Volume setting already has a slider; no further action required here
                break
            }
        }
    }
}

