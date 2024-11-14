import UIKit

class TelemetrySettingsViewController: UITableViewController {
    
    private enum TelemetryRow: Int, CaseIterable {
        case telemetryOptOut = 0
    }
    
    private static let cellIdentifiers: [TelemetryRow: String] = [
        .telemetryOptOut: "telemetryOptOut"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = GDLocalizedString("settings.section.telemetry")
        
        // Register the specific cell identifier
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "telemetryOptOut")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TelemetryRow.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let rowType = TelemetryRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let identifier = TelemetrySettingsViewController.cellIdentifiers[rowType] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        
        switch rowType {
        case .telemetryOptOut:
            cell.textLabel?.text = GDLocalizedString("settings.section.share_usage_data")
            cell.accessoryType = .none
            
            let telemetrySwitch = UISwitch()
            telemetrySwitch.isOn = !SettingsContext.shared.telemetryOptout
            telemetrySwitch.addTarget(self, action: #selector(telemetrySwitchChanged(_:)), for: .valueChanged)
            cell.accessoryView = telemetrySwitch
        }
        
        return cell
    }
    
    // MARK: - Action
    
    @objc private func telemetrySwitchChanged(_ sender: UISwitch) {
        let isOptedOut = !sender.isOn
        SettingsContext.shared.telemetryOptout = isOptedOut
        
        let alertTitle = GDLocalizedString("settings.telemetry.optout.alert_title")
        let alertMessage = GDLocalizedString("settings.telemetry.optout.alert_message")
        
        if isOptedOut {
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.confirm"), style: .default, handler: { _ in
                SettingsContext.shared.telemetryOptout = true
                sender.isOn = false
            }))
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: { _ in
                sender.isOn = true
                SettingsContext.shared.telemetryOptout = false
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            SettingsContext.shared.telemetryOptout = false
        }
    }
}

