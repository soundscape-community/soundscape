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
    
<<<<<<< Updated upstream
    private enum CalloutsRow: Int, CaseIterable {
        case all = 0
        case poi = 1
        case mobility = 2
        case beacon = 3
        case shake = 4
=======
    /// Rows in the "Callouts" section
    private enum CalloutsRow: Int, CaseIterable {
        case all = 0
        case soundEffects = 1
        case delays = 2
        case poi = 3
        case mobility = 4
        case safety = 5
        case intersection = 6
        case beacon = 7
        case shake = 8
>>>>>>> Stashed changes
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
        // IndexPath(row: 0, section: Section.telemetry.rawValue): "telemetry"
    ]
    
<<<<<<< Updated upstream
    private static let collapsibleCalloutIndexPaths: [IndexPath] = [
        IndexPath(row: CalloutsRow.poi.rawValue, section: Section.callouts.rawValue),
        IndexPath(row: CalloutsRow.mobility.rawValue, section: Section.callouts.rawValue),
        IndexPath(row: CalloutsRow.beacon.rawValue, section: Section.callouts.rawValue),
        IndexPath(row: CalloutsRow.shake.rawValue, section: Section.callouts.rawValue)
    ]
=======
    /// Which sub‑rows collapse/expand under "Allow Callouts"
    private static let collapsibleCalloutIndexPaths: [IndexPath] = CalloutsRow.allCases
        .filter { $0 != .all }
        .map { IndexPath(row: $0.rawValue, section: Section.callouts.rawValue) }
>>>>>>> Stashed changes
    
    // MARK: Properties

    @IBOutlet weak var largeBannerContainerView: UIView!

    // MARK: View Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        GDLogActionInfo("Opened 'Settings'")

        GDATelemetry.trackScreenView("settings")

        self.title = GDLocalizedString("settings.screen_title")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .general: return 6
        case .audio: return 1
        case .callouts: return SettingsContext.shared.automaticCalloutsEnabled ? CalloutsRow.allCases.count : 1
        case .streetPreview: return 1
        case .troubleshooting: return 1
        case .about: return 1
        // case .telemetry: return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = SettingsViewController.cellIdentifiers[indexPath]
        
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return tableView.dequeueReusableCell(withIdentifier: identifier ?? "default", for: indexPath)
        }

<<<<<<< Updated upstream
        switch sectionType {
=======
        if Section(rawValue: indexPath.section) == .callouts,
           let rowType = CalloutsRow(rawValue: indexPath.row),
           rowType == .soundEffects || rowType == .delays {
            let cell = makeProgrammaticCalloutCell(for: rowType)
            configureCalloutCell(cell, at: indexPath)
            return cell
        }
        
        let identifier = SettingsViewController.cellIdentifiers[indexPath] ?? "default"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier,
                                                 for: indexPath)
        
        switch Section(rawValue: indexPath.section) {
>>>>>>> Stashed changes
        case .callouts:
            let calloutCell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! CalloutSettingsCellView
            configureCalloutCell(calloutCell, at: indexPath)
            return calloutCell
            
<<<<<<< Updated upstream
        // case .telemetry:
        //     let cell = tableView.dequeueReusableCell(withIdentifier: identifier ?? "default", for: indexPath) as! TelemetrySettingsTableViewCell
        //     cell.parent = self
=======
        case .telemetry:
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! TelemetrySettingsTableViewCell
            cell.parent = self
>>>>>>> Stashed changes
            
        //     return cell
            
        case .audio:
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier ?? "default", for: indexPath) as! MixAudioSettingCell
            cell.delegate = self
            return cell
            
        default:
            return tableView.dequeueReusableCell(withIdentifier: identifier ?? "default", for: indexPath)
        }
        
    }
    
<<<<<<< Updated upstream
    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
=======
    private func configureCalloutCell(_ cell: CalloutSettingsCellView,
                                      at indexPath: IndexPath) {
        cell.delegate = self
        guard let rowType = CalloutsRow(rawValue: indexPath.row) else {
            return
        }
        
        switch rowType {
        case .all:
            cell.type = .all
        case .soundEffects:
            cell.type = .soundEffects
        case .delays:
            cell.type = .delays
        case .poi:
            cell.type = .poi
        case .mobility:
            // the "Mobility" toggle now maps to the transportation case
            cell.type = .transportation
        case .safety:
            cell.type = .safety
        case .intersection:
            cell.type = .intersection
        case .beacon:
            cell.type = .beacon
        case .shake:
            cell.type = .shake
        }
    }

    private func makeProgrammaticCalloutCell(for rowType: CalloutsRow) -> CalloutSettingsCellView {
        let cell = CalloutSettingsCellView(style: .subtitle, reuseIdentifier: "callout.dynamic.\(rowType.rawValue)")
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(named: "Background 1")
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = Colors.Foreground.primary

        let settingSwitch = UISwitch(frame: .zero)
        settingSwitch.onTintColor = .white
        settingSwitch.thumbTintColor = UIColor(named: "Background Base")
        settingSwitch.addTarget(cell, action: #selector(CalloutSettingsCellView.onSettingValueChanged(_:)), for: .valueChanged)
        cell.accessoryView = settingSwitch

        switch rowType {
        case .soundEffects:
            cell.textLabel?.text = GDLocalizedString("callouts.sound_effects")
            cell.detailTextLabel?.text = GDLocalizedString("callouts.sound_effects.info")
        case .delays:
            cell.textLabel?.text = GDLocalizedString("callouts.delays")
            cell.detailTextLabel?.text = GDLocalizedString("callouts.delays.info")
        default:
            break
        }

        return cell
    }

    // MARK: Headers & Footers
    
    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
>>>>>>> Stashed changes
        guard let sectionType = Section(rawValue: section) else { return nil }

        switch sectionType {
        case .general: return GDLocalizedString("settings.section.general")
        case .audio: return GDLocalizedString("settings.audio.media_controls")
        case .callouts: return GDLocalizedString("menu.manage_callouts")
        case .about: return GDLocalizedString("settings.section.about")
        case .streetPreview: return GDLocalizedString("preview.title")
        case .troubleshooting: return GDLocalizedString("settings.section.troubleshooting")
        // case .telemetry: return GDLocalizedString("settings.section.telemetry")
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        switch sectionType {
        case .audio: return GDLocalizedString("settings.audio.mix_with_others.description")
        case .streetPreview: return GDLocalizedString("preview.include_unnamed_roads.subtitle")
        // case .telemetry: return GDLocalizedString("settings.section.telemetry.footer")
        default: return nil
        }
    }
}

extension SettingsViewController: MixAudioSettingCellDelegate {
    func onSettingValueChanged(_ cell: MixAudioSettingCell, settingSwitch: UISwitch) {
        // Note: The UI for this setting is "Enable Media Controls" but the setting is stored as
        //       "Mixes with Others" (the inverse of "Enable Media Controls")
        
        guard settingSwitch.isOn else {
            // If the setting switch is now off, the user disabled media controls. This doesn't
            // require a warning alert, so just set mixesWithOthers to true and return.
            updateSetting(true)
            return
        }
        
        // Otherwise, the user is turning on media controls, so we need to show a warning to make sure
        // they understand what this change means in terms of how other audio apps will stop Soundscape
        // from playing. This warning was added based on bug bash feedback on 12/3/20.
        // Show an alert indicating that the user can download an enhanced version of the voice in Settings
        let alert = UIAlertController(title: GDLocalizedString("general.alert.confirmation_title"),
                                      message: GDLocalizedString("setting.audio.mix_with_others.confirmation"),
                                      preferredStyle: .alert)
        
        let mixAction = UIAlertAction(title: GDLocalizedString("settings.audio.mix_with_others.title"), style: .default) { [weak self] (_) in
            // Make the setting switch - turn off mixesWithOthers
            self?.updateSetting(false)
            self?.focusOnCell(cell)
        }
        alert.addAction(mixAction)
        alert.preferredAction = mixAction
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: { [weak self] (_) in
            // Toggle the setting back off
            settingSwitch.isOn = false
            
            // Track that the user decided not to enable media controls
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
