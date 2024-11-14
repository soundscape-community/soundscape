import UIKit

class CalloutSettingsViewController: UITableViewController {
    
    private enum CalloutsRow: Int, CaseIterable {
        case all = 0
        case poi = 1
        case mobility = 2
        case beacon = 3
        case shake = 4
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
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "allCallouts")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "poiCallouts")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "mobilityCallouts")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "beaconCallouts")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "shakeCallouts")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CalloutsRow.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let rowType = CalloutsRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let identifier = CalloutSettingsViewController.cellIdentifiers[rowType] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.selectionStyle = .none
        
        switch rowType {
        case .all:
            cell.textLabel?.text = GDLocalizedString("menu.manage_callouts.all")
            let switchView = UISwitch(frame: .zero)
            switchView.setOn(automaticCalloutsEnabled, animated: true)
            switchView.tag = CalloutsRow.all.rawValue
            switchView.addTarget(self, action: #selector(toggleCalloutSetting(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        case .poi:
            cell.textLabel?.text = GDLocalizedString("menu.manage_callouts.poi")
            let switchView = UISwitch(frame: .zero)
            switchView.setOn(poiCalloutsEnabled, animated: true)
            switchView.tag = CalloutsRow.poi.rawValue
            switchView.addTarget(self, action: #selector(toggleCalloutSetting(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        case .mobility:
            cell.textLabel?.text = GDLocalizedString("menu.manage_callouts.mobility")
            let switchView = UISwitch(frame: .zero)
            switchView.setOn(mobilityCalloutsEnabled, animated: true)
            switchView.tag = CalloutsRow.mobility.rawValue
            switchView.addTarget(self, action: #selector(toggleCalloutSetting(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        case .beacon:
            cell.textLabel?.text = GDLocalizedString("menu.manage_callouts.beacon")
            let switchView = UISwitch(frame: .zero)
            switchView.setOn(beaconCalloutsEnabled, animated: true)
            switchView.tag = CalloutsRow.beacon.rawValue
            switchView.addTarget(self, action: #selector(toggleCalloutSetting(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        case .shake:
            cell.textLabel?.text = GDLocalizedString("menu.manage_callouts.shake")
            let switchView = UISwitch(frame: .zero)
            switchView.setOn(shakeCalloutsEnabled, animated: true)
            switchView.tag = CalloutsRow.shake.rawValue
            switchView.addTarget(self, action: #selector(toggleCalloutSetting(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        }
        
        return cell
    }
    
    // Toggle actions for each callout setting switch
    @objc private func toggleCalloutSetting(_ sender: UISwitch) {
        switch CalloutsRow(rawValue: sender.tag) {
        case .all:
            automaticCalloutsEnabled = sender.isOn
            SettingsContext.shared.automaticCalloutsEnabled = sender.isOn
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
        
        // Update table view based on automatic callouts state
        if sender.tag == CalloutsRow.all.rawValue {
            tableView.reloadData()
        }
    }
}

