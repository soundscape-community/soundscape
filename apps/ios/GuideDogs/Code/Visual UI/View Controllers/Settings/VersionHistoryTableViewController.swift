//
//  VersionHistoryTableViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

class VersionHistoryTableViewController: BaseTableViewController {
    private static let featureCellReuseIdentifier = "featureCell"

    // MARK: - Properties

    private let features = NewFeatures.allFeaturesHistory()
    private(set) var largeBannerContainerView: UIView! = UIView(frame: .zero)

    init() {
        super.init(style: .grouped)
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = GDLocalizedString("settings.about.title.whats_new")

        updateLargeBannerContainerViewFrame()
        tableView.tintColor = Colors.Foreground.primary
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.sectionHeaderHeight = 18
        tableView.sectionFooterHeight = 18
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateLargeBannerContainerViewFrame()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        GDATelemetry.trackScreenView("settings.about.whats_new")
    }
    
    // MARK: - Helper methods

    private func versions() -> [VersionString] {
        guard let versions = features?.keys.sorted(by: { $1 < $0 }) else { return [] }
        return versions
    }
    
    private func features(for section: Int) -> [FeatureInfo] {
        let versionKey = versions()[section]
        return features?[versionKey] ?? []
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return versions().count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return GDLocalizedString("settings.version.history.version", versions()[section].string)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return features(for: section).count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VersionHistoryTableViewController.featureCellReuseIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: VersionHistoryTableViewController.featureCellReuseIdentifier)

        let feature = features(for: indexPath.section)[indexPath.row]
        
        cell.textLabel?.text = feature.localizedTitle
        cell.detailTextLabel?.text = feature.localizedDescription
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = Colors.Foreground.primary
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = UIColor(red: 0.6705882353, green: 0.9607843137, blue: 0.9607843137, alpha: 1)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.backgroundColor = Colors.Background.primary

        return cell
    }
 
    // MARK: - Table view data delegate

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? UITableViewHeaderFooterView else { return }
        
        view.textLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        view.textLabel?.textColor = UIColor.white
        view.backgroundView?.backgroundColor = self.view.backgroundColor
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = NewFeaturesViewController(nibName: "NewFeaturesView", bundle: nil)

        vc.features = [features(for: indexPath.section)[indexPath.row]]
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        vc.accessibilityViewIsModal = true

        self.present(vc, animated: !UIAccessibility.isVoiceOverRunning, completion: nil)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)

        cell.detailTextLabel?.textColor = UIColor(red: 0.6705882353, green: 0.9607843137, blue: 0.9607843137, alpha: 1)
    }

    private func updateLargeBannerContainerViewFrame() {
        let headerHeight = largeBannerContainerView.frame.height
        let headerWidth = tableView.bounds.width

        guard headerWidth > 0 else {
            return
        }

        largeBannerContainerView.frame = CGRect(x: 0, y: 0, width: headerWidth, height: headerHeight)

        if headerHeight > 0 {
            tableView.tableHeaderView = largeBannerContainerView
        } else if tableView.tableHeaderView != nil {
            tableView.tableHeaderView = nil
        }
    }
    
}

extension VersionHistoryTableViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerView.setHeight(height)
        updateLargeBannerContainerViewFrame()
        tableView.reloadData()
    }
    
}
