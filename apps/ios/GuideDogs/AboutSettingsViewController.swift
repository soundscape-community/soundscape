/*
import UIKit

class AboutSettingsViewController: UITableViewController {

    private enum AboutRow: Int, CaseIterable {
        case whatsNew = 0
        case privacyPolicy = 1
        case serviceAgreement = 2
        case thirdPartyNotices = 3
        case copyrightNotices = 4
    }
    
    private static let cellIdentifiers: [AboutRow: String] = [
        .whatsNew: "whatsNew",
        .privacyPolicy: "privacyPolicy",
        .serviceAgreement: "serviceAgreement",
        .thirdPartyNotices: "thirdPartyNotices",
        .copyrightNotices: "copyrightNotices"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = GDLocalizedString("settings.section.about")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "default")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AboutRow.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let rowType = AboutRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let identifier = AboutSettingsViewController.cellIdentifiers[rowType] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        cell.accessoryType = .disclosureIndicator
        
        switch rowType {
        case .whatsNew:
            cell.textLabel?.text = GDLocalizedString("settings.about.title.whats_new")
        case .privacyPolicy:
            cell.textLabel?.text = GDLocalizedString("settings.about.title.privacy")
        case .serviceAgreement:
            cell.textLabel?.text = GDLocalizedString("settings.about.title.service_agreement")
        case .thirdPartyNotices:
            cell.textLabel?.text = GDLocalizedString("settings.about.title.third_party")
        case .copyrightNotices:
            cell.textLabel?.text = GDLocalizedString("settings.about.title.copyright")
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let rowType = AboutRow(rawValue: indexPath.row) else { return }
        
        switch rowType {
        case .whatsNew:
            navigateToWebView(withTitle: GDLocalizedString("settings.about.title.whats_new"), url: "https://example.com/whats-new")
        case .privacyPolicy:
            navigateToWebView(withTitle: GDLocalizedString("settings.about.title.privacy"), url: "https://example.com/privacy-policy")
        case .serviceAgreement:
            navigateToWebView(withTitle: GDLocalizedString("settings.about.title.service_agreement"), url: "https://example.com/service-agreement")
        case .thirdPartyNotices:
            navigateToWebView(withTitle: GDLocalizedString("settings.about.title.third_party"), url: "https://example.com/third-party-notices")
        case .copyrightNotices:
            navigateToWebView(withTitle: GDLocalizedString("settings.about.title.copyright"), url: "https://example.com/copyright-notices")
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    
    private func navigateToWebView(withTitle title: String, url: String) {
        let webViewController = WebViewController()
        webViewController.title = title
        webViewController.urlString = url
        navigationController?.pushViewController(webViewController, animated: true)
    }
}
*/
import UIKit

class AboutSettingsViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register the "whatsNew" cell identifier to avoid dequeuing errors
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "whatsNew")
        
        self.title = GDLocalizedString("settings.section.about")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 // Assuming one row for demonstration; adjust based on your content
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "whatsNew", for: indexPath)
        cell.textLabel?.text = GDLocalizedString("about.whats_new") // Customize cell content as needed
        return cell
    }
}

