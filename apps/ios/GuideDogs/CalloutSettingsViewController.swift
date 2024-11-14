import UIKit

class CalloutSettingsViewController: UITableViewController {
    
    private enum CalloutsRow: Int, CaseIterable {
        case all = 0
        case poi
        case mobility
        case beacon
        case shake
    }
    
    private static let cellIdentifiers: [CalloutsRow: String] = [
        .all: "allCallouts",
        .poi: "poiCallouts",
        .mobility: "mobilityCallouts",
        .beacon: "beaconCallouts",
        .shake: "shakeCallouts"
    ]
    
    // Properties to store the states of each callout setting
    private var automaticCalloutsEnabled = SettingsContext.shared.automaticCalloutsEnabled
    private var poiCalloutsEnabled = true
    private var mobilityCalloutsEnabled = true
    private var beaconCalloutsEnabled = true
    private var shakeCalloutsEnabled = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = GDLocalizedString("menu.manage_callouts")
        
        // Register the cells
        for identifier in CalloutSettingsViewController.cellIdentifiers.values {
            self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: identifier)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return automaticCalloutsEnabled ? CalloutsRow.allCases.count : 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let rowType = CalloutsRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let identifier = CalloutSettingsViewController.cellIdentifiers[rowType] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.selectionStyle = .none
        
        // Configure the cell based on the row type
        let switchView = UISwitch(frame: .zero)
        switchView.addTarget(self, action: #selector(toggleCalloutSetting(_:)), for: .valueChanged)
        switchView.tag = rowType.rawValue
        cell.accessoryView = switchView
        
        switch rowType {
        case .all:
            cell.textLabel?.text = GDLocalizedString("Allow Callouts")
            switchView.setOn(automaticCalloutsEnabled, animated: true)
        case .poi:
            cell.textLabel?.text = GDLocalizedString("Places and Landmarks")
            switchView.setOn(poiCalloutsEnabled, animated: true)
        case .mobility:
            cell.textLabel?.text = GDLocalizedString("Mobility")
            switchView.setOn(mobilityCalloutsEnabled, animated: true)
        case .beacon:
            cell.textLabel?.text = GDLocalizedString("Distance to the Audio Beacon")
            switchView.setOn(beaconCalloutsEnabled, animated: true)
        case .shake:
            cell.textLabel?.text = GDLocalizedString("Repeat Callouts")
            switchView.setOn(shakeCalloutsEnabled, animated: true)
        }
        
        return cell
    }
    
    // Toggle actions for each callout setting switch
    @objc private func toggleCalloutSetting(_ sender: UISwitch) {
        switch CalloutsRow(rawValue: sender.tag) {
        case .all:
            automaticCalloutsEnabled = sender.isOn
            SettingsContext.shared.automaticCalloutsEnabled = sender.isOn
            tableView.reloadData()  // Refresh the table to show/hide rows based on the "all" toggle
        case .poi:
            poiCalloutsEnabled = sender.isOn
        case .mobility:
            mobilityCalloutsEnabled = sender.isOn
        case .beacon:
            beaconCalloutsEnabled = sender.isOn
        case .shake:
            shakeCalloutsEnabled = sender.isOn
        case .none:
            break
        }
    }
}

