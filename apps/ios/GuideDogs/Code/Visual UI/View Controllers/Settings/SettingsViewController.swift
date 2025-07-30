//
//  SettingsViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

class SettingsViewController: BaseTableViewController {
    
    private enum Section: Int, CaseIterable {
        case general = 0
        case audio = 1
        case callouts = 2
        case streetPreview = 3
        case troubleshooting = 4
        case about = 5
        // case telemetry = 6
    }
    
    /// 7 rows in the Callouts section: All, Places, Mobility, Safety, Intersections, Beacon, Shake
    private enum CalloutsRow: Int, CaseIterable {
        case all = 0
        case poi = 1
        case mobility = 2
        case safety = 3
        case intersection = 4
        case beacon = 5
        case shake = 6
    }
    
    /// Map each indexPath to its storyboard reuseIdentifier
    private static let cellIdentifiers: [IndexPath: String] = [
        // General
        IndexPath(row: 0, section: Section.general.rawValue): "languageAndRegion",
        IndexPath(row: 1, section: Section.general.rawValue): "voice",
        IndexPath(row: 2, section: Section.general.rawValue): "beaconSettings",
        IndexPath(row: 3, section: Section.general.rawValue): "volumeSettings",
        IndexPath(row: 4, section: Section.general.rawValue): "manageDevices",
        IndexPath(row: 5, section: Section.general.rawValue): "siriShortcuts",
        
        // Audio
        IndexPath(row: 0, section: Section.audio.rawValue): "mixAudio",

        // Callouts
        IndexPath(row: CalloutsRow.all.rawValue,        section: Section.callouts.rawValue): "allCallouts",
        IndexPath(row: CalloutsRow.poi.rawValue,        section: Section.callouts.rawValue): "poiCallouts",
        IndexPath(row: CalloutsRow.mobility.rawValue,   section: Section.callouts.rawValue): "mobilityCallouts",
        IndexPath(row: CalloutsRow.safety.rawValue,     section: Section.callouts.rawValue): "safetyCallouts",
        IndexPath(row: CalloutsRow.intersection.rawValue,section: Section.callouts.rawValue): "intersectionCallouts",
        IndexPath(row: CalloutsRow.beacon.rawValue,     section: Section.callouts.rawValue): "beaconCallouts",
        IndexPath(row: CalloutsRow.shake.rawValue,      section: Section.callouts.rawValue): "shakeCallouts",

        // Other
        IndexPath(row: 0, section: Section.streetPreview.rawValue): "streetPreview",
        IndexPath(row: 0, section: Section.troubleshooting.rawValue): "troubleshooting",
        IndexPath(row: 0, section: Section.about.rawValue): "about",
        // IndexPath(row: 0, section: Section.telemetry.rawValue): "telemetry"
    ]
    
    // MARK: Properties

    @IBOutlet weak var largeBannerContainerView: UIView!

    // MARK: View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        GDLogActionInfo("Opened 'Settings'")
        GDATelemetry.trackScreenView("settings")
        self.title = GDLocalizedString("settings.screen_title")
    }
    
    // MARK: Sections & Rows

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .general:
            return 6
        case .audio:
            return 1
        case .callouts:
            return SettingsContext.shared.automaticCalloutsEnabled
                ? CalloutsRow.allCases.count
                : 1
        case .streetPreview, .troubleshooting, .about:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = SettingsViewController.cellIdentifiers[indexPath] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier,
                                                 for: indexPath)
        
        if let sectionType = Section(rawValue: indexPath.section) {
            switch sectionType {
            case .callouts:
                configureCalloutCell(cell as! CalloutSettingsCellView, at: indexPath)
            case .audio:
                (cell as! MixAudioSettingCell).delegate = self
            default:
                break
            }
        }
        return cell
    }
    
    private func configureCalloutCell(_ cell: CalloutSettingsCellView,
                                      at indexPath: IndexPath) {
        cell.delegate = self
        guard let rowType = CalloutsRow(rawValue: indexPath.row) else { return }
        switch rowType {
        case .all:          cell.type = .all
        case .poi:          cell.type = .poi
        case .mobility:     cell.type = .transportation
        case .safety:       cell.type = .safety
        case .intersection: cell.type = .intersection
        case .beacon:       cell.type = .beacon
        case .shake:        cell.type = .shake
        }
    }

    // MARK: Headers & Footers

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .general:       return GDLocalizedString("settings.section.general")
        case .audio:         return GDLocalizedString("settings.audio.media_controls")
        case .callouts:      return GDLocalizedString("menu.manage_callouts")
        case .about:         return GDLocalizedString("settings.section.about")
        case .streetPreview: return GDLocalizedString("preview.title")
        case .troubleshooting:
                             return GDLocalizedString("settings.section.troubleshooting")
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .general:
            return GDLocalizedString("settings.section.general.footer")
        case .audio:
            return GDLocalizedString("settings.audio.mix_with_others.description")
        case .callouts:
            return GDLocalizedString("settings.callouts.footer")
        case .streetPreview:
            return GDLocalizedString("preview.include_unnamed_roads.subtitle")
        case .troubleshooting:
            return GDLocalizedString("settings.section.troubleshooting.footer")
        case .about:
            return GDLocalizedString("settings.section.about.footer")
        }
    }
}

extension SettingsViewController: MixAudioSettingCellDelegate {
    func onSettingValueChanged(_ cell: MixAudioSettingCell,
                               settingSwitch: UISwitch) {
        guard settingSwitch.isOn else {
            updateSetting(true)
            return
        }
        let alert = UIAlertController(
            title:   GDLocalizedString("general.alert.confirmation_title"),
            message: GDLocalizedString("setting.audio.mix_with_others.confirmation"),
            preferredStyle: .alert
        )
        let mixAction = UIAlertAction(
            title: GDLocalizedString("settings.audio.mix_with_others.title"),
            style: .default
        ) { [weak self] _ in
            self?.updateSetting(false)
            self?.focusOnCell(cell)
        }
        alert.addAction(mixAction)
        alert.preferredAction = mixAction
        alert.addAction(UIAlertAction(
            title: GDLocalizedString("general.alert.cancel"),
            style: .cancel
        ) { [weak self] _ in
            settingSwitch.isOn = false
            GDATelemetry.track("settings.mix_audio.cancel",
                               with: ["context": "app_settings"])
            self?.focusOnCell(cell)
        })
        present(alert, animated: true)
    }
    
    private func updateSetting(_ newValue: Bool) {
        SettingsContext.shared.audioSessionMixesWithOthers = newValue
        AppContext.shared.audioEngine.mixWithOthers = newValue
        GDATelemetry.track("settings.mix_audio",
                           with: ["value": "\(newValue)", "context": "app_settings"])
    }
    
    private func focusOnCell(_ cell: MixAudioSettingCell) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: cell)
        }
    }
}

extension SettingsViewController: CalloutSettingsCellViewDelegate {
    func onCalloutSettingChanged(_ type: CalloutSettingCellType) {
        guard type == .all else { return }
        let paths = SettingsViewController.collapsibleCalloutIndexPaths
        if SettingsContext.shared.automaticCalloutsEnabled {
            tableView.insertRows(at: paths, with: .automatic)
        } else {
            tableView.deleteRows(at: paths, with: .automatic)
        }
    }
}

extension SettingsViewController: LargeBannerContainerView {
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerView.setHeight(height)
        tableView.reloadData()
    }
}

