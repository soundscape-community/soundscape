import UIKit

class StreetPreviewViewController: UITableViewController {
    
    private enum StreetPreviewRow: Int, CaseIterable {
        case includeUnnamedRoads = 0
    }
    
    private static let cellIdentifiers: [StreetPreviewRow: String] = [
        .includeUnnamedRoads: "streetPreviewIncludeUnnamedRoads"
    ]
    
    // Property to hold the current state of the "Include Unnamed Roads" setting
    private var includeUnnamedRoads = SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = GDLocalizedString("settings.section.street_preview")
        
        // Register the specific cell identifier
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "streetPreviewIncludeUnnamedRoads")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return StreetPreviewRow.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let rowType = StreetPreviewRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let identifier = StreetPreviewViewController.cellIdentifiers[rowType] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.selectionStyle = .none
        
        switch rowType {
        case .includeUnnamedRoads:
            cell.textLabel?.text = GDLocalizedString("preview.include_unnamed_roads.subtitle")
            let switchView = UISwitch(frame: .zero)
            switchView.setOn(includeUnnamedRoads, animated: true)
            switchView.tag = StreetPreviewRow.includeUnnamedRoads.rawValue
            switchView.addTarget(self, action: #selector(toggleIncludeUnnamedRoads(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        }
        
        return cell
    }
    
    // Action for the "Include Unnamed Roads" switch
    @objc private func toggleIncludeUnnamedRoads(_ sender: UISwitch) {
        includeUnnamedRoads = sender.isOn
        SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads = sender.isOn
        // Optionally, post a notification or perform any additional actions when this setting changes
    }
}

