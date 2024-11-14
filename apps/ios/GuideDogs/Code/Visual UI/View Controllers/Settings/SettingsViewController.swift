//
//  SettingsViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

//
//  SettingsViewController.swift
//  Soundscape
//
import UIKit
import AppCenterAnalytics

class SettingsViewController: BaseTableViewController {

    @IBOutlet weak var largeBannerContainerView: UIView! // IBOutlet for the banner container view

    private enum Section: Int, CaseIterable {
        case general = 0
        case audio
        case callouts
        case streetPreview
        case troubleshooting
        case about
        case telemetry
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = GDLocalizedString("settings.screen_title")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        
        GDLogActionInfo("Opened 'Settings'")
        GDATelemetry.trackScreenView("settings")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 // Each section has one row to navigate to its own view controller
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
        cell.accessoryType = .disclosureIndicator // Show an arrow to indicate navigation

        switch Section(rawValue: indexPath.section) {
        case .general:
            cell.textLabel?.text = GDLocalizedString("settings.section.general")
        case .audio:
            cell.textLabel?.text = GDLocalizedString("settings.audio.media_controls")
        case .callouts:
            cell.textLabel?.text = GDLocalizedString("menu.manage_callouts")
        case .streetPreview:
            cell.textLabel?.text = GDLocalizedString("settings.section.street_preview")
        case .troubleshooting:
            cell.textLabel?.text = GDLocalizedString("settings.section.troubleshooting")
        case .about:
            cell.textLabel?.text = GDLocalizedString("settings.section.about")
        case .telemetry:
            cell.textLabel?.text = GDLocalizedString("settings.section.telemetry")
        default:
            cell.textLabel?.text = ""
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let section = Section(rawValue: indexPath.section)
        let viewController: UIViewController
        
        switch section {
        case .general:
            viewController = GeneralSettingsViewController()
        case .audio:
            viewController = AudioSettingsViewController()
        case .callouts:
            viewController = CalloutSettingsViewController()
        case .streetPreview:
            viewController = StreetPreviewViewController()
        case .troubleshooting:
            viewController = TroubleshootingViewController()
        case .about:
            viewController = AboutSettingsViewController() // Navigates to AboutSettingsViewController
        case .telemetry:
            viewController = TelemetrySettingsViewController()
        default:
            return
        }
        
        navigationController?.pushViewController(viewController, animated: true)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .general: return GDLocalizedString("settings.section.general")
        case .audio: return GDLocalizedString("settings.audio.media_controls")
        case .callouts: return GDLocalizedString("menu.manage_callouts")
        case .about: return GDLocalizedString("settings.section.about")
        case .streetPreview: return GDLocalizedString("preview.title")
        case .troubleshooting: return GDLocalizedString("settings.section.troubleshooting")
        case .telemetry: return GDLocalizedString("settings.section.telemetry")
        default: return nil
        }
    }
}


/*
import UIKit
import AppCenterAnalytics

class SettingsViewController: BaseTableViewController {

    private enum Section: Int, CaseIterable {
        case general = 0
        case audio = 1
        case callouts = 2
        case streetPreview = 3
        case troubleshooting = 4
        case about = 5
        case telemetry = 6
    }
    
    private enum CalloutsRow: Int, CaseIterable {
        case all = 0
        case poi = 1
        case mobility = 2
        case beacon = 3
        case shake = 4
    }
    
    private static let cellIdentifiers: [IndexPath: String] = [
        IndexPath(row: 0, section: Section.general.rawValue): "languageAndRegion",
        IndexPath(row: 1, section: Section.general.rawValue): "voice",
        IndexPath(row: 2, section: Section.general.rawValue): "beaconSettings",
        IndexPath(row: 3, section: Section.general.rawValue): "volumeSettings",
        IndexPath(row: 4, section: Section.general.rawValue): "manageDevices",
        IndexPath(row: 5, section: Section.general.rawValue): "siriShortcuts",

        IndexPath(row: 0, section: Section.audio.rawValue): "mixAudio",

        IndexPath(row: CalloutsRow.all.rawValue, section: Section.callouts.rawValue): "allCallouts",
        IndexPath(row: CalloutsRow.poi.rawValue, section: Section.callouts.rawValue): "poiCallouts",
        IndexPath(row: CalloutsRow.mobility.rawValue, section: Section.callouts.rawValue): "mobilityCallouts",
        IndexPath(row: CalloutsRow.beacon.rawValue, section: Section.callouts.rawValue): "beaconCallouts",
        IndexPath(row: CalloutsRow.shake.rawValue, section: Section.callouts.rawValue): "shakeCallouts",

        IndexPath(row: 0, section: Section.streetPreview.rawValue): "streetPreview",
        IndexPath(row: 0, section: Section.troubleshooting.rawValue): "troubleshooting",
        IndexPath(row: 0, section: Section.about.rawValue): "about",
        IndexPath(row: 0, section: Section.telemetry.rawValue): "telemetry"
    ]
    
    private static let collapsibleCalloutIndexPaths: [IndexPath] = [
        IndexPath(row: CalloutsRow.poi.rawValue, section: Section.callouts.rawValue),
        IndexPath(row: CalloutsRow.mobility.rawValue, section: Section.callouts.rawValue),
        IndexPath(row: CalloutsRow.beacon.rawValue, section: Section.callouts.rawValue),
        IndexPath(row: CalloutsRow.shake.rawValue, section: Section.callouts.rawValue)
    ]
    
    // MARK: Properties

    @IBOutlet weak var largeBannerContainerView: UIView!
    
    private var expandedSections: Set<Int> = []
    
    // Section Descriptions
    private static let sectionDescriptions: [Section: String] = [
        .general: GDLocalizedString("settings.section.general"),
        .audio: GDLocalizedString("settings.audio.media_controls"),
        .callouts: GDLocalizedString("menu.manage_callouts"),
        .streetPreview: GDLocalizedString("settings.section.street_preview"),
        .troubleshooting: GDLocalizedString("settings.section.troubleshooting"),
        .about: GDLocalizedString("settings.section.about"),
        .telemetry: GDLocalizedString("settings.section.telemetry")
    ]

    // MARK: View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        GDLogActionInfo("Opened 'Settings'")

        GDATelemetry.trackScreenView("settings")

        self.title = GDLocalizedString("settings.screen_title")
        expandedSections = []
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        if expandedSections.contains(section) {
            switch sectionType {
            case .general: return 6
            case .audio: return 1
            case .callouts:
                return SettingsContext.shared.automaticCalloutsEnabled ? 5 : 0
            case .streetPreview, .troubleshooting, .about, .telemetry:
                return 1
            }
        }
        return 0
    }


    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return expandedSections.contains(indexPath.section) ? UITableView.automaticDimension : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard expandedSections.contains(indexPath.section) else {
            return UITableViewCell()
        }
        
        let identifier = SettingsViewController.cellIdentifiers[indexPath]
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier ?? "default", for: indexPath)
        
        switch Section(rawValue: indexPath.section) {
        case .callouts:
            configureCalloutCell(cell as! CalloutSettingsCellView, at: indexPath)
        case .telemetry:
            (cell as! TelemetrySettingsTableViewCell).parent = self
        case .audio:
            (cell as! MixAudioSettingCell).delegate = self
        default:
            break
        }
        
        return cell
    }
    
    private func configureCalloutCell(_ cell: CalloutSettingsCellView, at indexPath: IndexPath) {
        cell.delegate = self
        if let rowType = CalloutsRow(rawValue: indexPath.row) {
            switch rowType {
            case .all:
                cell.type = .all
            case .poi:
                cell.type = .poi
            case .mobility:
                cell.type = .mobility
            case .beacon:
                cell.type = .beacon
            case .shake:
                cell.type = .shake
            }
        }
    }

    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        switch sectionType {
        case .general: return GDLocalizedString("settings.section.general")
        case .audio: return GDLocalizedString("settings.audio.media_controls")
        case .callouts: return GDLocalizedString("menu.manage_callouts")
        case .about: return GDLocalizedString("settings.section.about")
        case .streetPreview: return GDLocalizedString("preview.title")
        case .troubleshooting: return GDLocalizedString("settings.section.troubleshooting")
        case .telemetry: return GDLocalizedString("settings.section.telemetry")
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        
        if expandedSections.contains(section) {
            return SettingsViewController.sectionDescriptions[sectionType]
        }

        switch sectionType {
        case .audio: return GDLocalizedString("settings.audio.mix_with_others.description")
        case .streetPreview: return GDLocalizedString("preview.include_unnamed_roads.subtitle")
        case .telemetry: return GDLocalizedString("settings.section.telemetry.footer")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleHeaderTap(_:))))
        header.tag = section

        
        header.textLabel?.textColor = .white
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)

       
        header.contentView.backgroundColor = UIColor(named: "HeaderBackgroundColor")
        header.layer.borderColor = UIColor.clear.cgColor
        header.layer.borderWidth = 0.0
        header.layer.cornerRadius = 8.0
        header.layer.masksToBounds = true
        
        header.contentView.layoutMargins = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
        // ">" icon
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = .white
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        header.contentView.addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            chevronImageView.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -15),
            chevronImageView.centerYAnchor.constraint(equalTo: header.contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 20),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    @objc private func handleHeaderTap(_ gesture: UITapGestureRecognizer) {
        guard let header = gesture.view as? UITableViewHeaderFooterView else { return }
        let section = header.tag
        
        if expandedSections.contains(section) {
            expandedSections.remove(section)
            tableView.reloadSections(IndexSet(integer: section), with: .automatic)
            UIAccessibility.post(notification: .announcement, argument: "Section collapsed")
        } else {
            expandedSections.insert(section)
            tableView.reloadSections(IndexSet(integer: section), with: .automatic)
            UIAccessibility.post(notification: .announcement, argument: "Section expanded")
        }
    }

}

extension SettingsViewController: MixAudioSettingCellDelegate {
    func onSettingValueChanged(_ cell: MixAudioSettingCell, settingSwitch: UISwitch) {
        guard settingSwitch.isOn else {
            updateSetting(true)
            return
        }

        let alert = UIAlertController(title: GDLocalizedString("general.alert.confirmation_title"),
                                      message: GDLocalizedString("setting.audio.mix_with_others.confirmation"),
                                      preferredStyle: .alert)
        
        let mixAction = UIAlertAction(title: GDLocalizedString("settings.audio.mix_with_others.title"), style: .default) { [weak self] (_) in
            self?.updateSetting(false)
            self?.focusOnCell(cell)
        }
        alert.addAction(mixAction)
        alert.preferredAction = mixAction
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: { [weak self] (_) in
            settingSwitch.isOn = false
            GDATelemetry.track("settings.mix_audio.cancel", with: ["context": "app_settings"])
            self?.focusOnCell(cell)
        }))
        
        present(alert, animated: true)
    }

    private func updateSetting(_ newValue: Bool) {
        SettingsContext.shared.audioSessionMixesWithOthers = newValue
        AppContext.shared.audioEngine.mixWithOthers = newValue
        
        GDATelemetry.track("settings.mix_audio",
                           with: ["value": "\(SettingsContext.shared.audioSessionMixesWithOthers)",
                                  "context": "app_settings"])
    }
    
    private func focusOnCell(_ cell: MixAudioSettingCell) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: cell)
        }
    }
}

extension SettingsViewController: CalloutSettingsCellViewDelegate {
    func onCalloutSettingChanged(_ type: CalloutSettingCellType) {
        guard type == .all else {
            return
        }
        
        let indexPaths = SettingsViewController.collapsibleCalloutIndexPaths
        
        if SettingsContext.shared.automaticCalloutsEnabled && !tableView.contains(indexPaths: indexPaths) {
            tableView.insertRows(at: indexPaths, with: .automatic)
        } else if !SettingsContext.shared.automaticCalloutsEnabled && tableView.contains(indexPaths: indexPaths) {
            tableView.deleteRows(at: indexPaths, with: .automatic)
        }
    }
}

extension SettingsViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerView.setHeight(height)
        tableView.reloadData()
    }
}

*/
