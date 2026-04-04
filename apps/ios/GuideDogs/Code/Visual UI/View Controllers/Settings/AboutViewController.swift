//
//  AboutViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit
import SafariServices
import CocoaLumberjackSwift

class AboutHeaderCell: UITableViewCell {
    private let logoImageView = UIImageView(image: UIImage(named: "launchScreenLogo"))
    private let titleLabel = UILabel()
    private let versionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configureViewHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configureViewHierarchy()
    }

    func configure(versionText: String) {
        versionLabel.text = versionText
    }

    private func configureViewHierarchy() {
        selectionStyle = .none
        backgroundColor = Colors.Background.primary
        contentView.backgroundColor = Colors.Background.primary

        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        logoImageView.contentMode = .scaleAspectFit

        titleLabel.text = GDLocalizationUnnecessary("Soundscape")
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.textColor = Colors.Foreground.primary

        versionLabel.font = .preferredFont(forTextStyle: .subheadline)
        versionLabel.adjustsFontForContentSizeCategory = true
        versionLabel.textAlignment = .center
        versionLabel.numberOfLines = 0
        versionLabel.textColor = Colors.Foreground.primary

        contentView.addSubview(logoImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            versionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            versionLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
    }
}

class AboutApplicationViewController: BaseTableViewController {
    private static let aboutHeaderHeight: CGFloat = 220
    private static let thirdPartyNoticesStoryboardIdentifier = "thirdPartyNotices"
    
    // MARK: Cell Content
    private enum NavigationTarget {
        case versionHistory
        case thirdPartyNotices
    }
    
    private struct AboutLinkCellModel {
        let localizedTitle: String
        
        let navigationTarget: NavigationTarget?
        let url: URL?
        
        let telemetryEventName: String?
        
        init(localizedTitle: String, url: URL, event: String? = nil) {
            self.localizedTitle = localizedTitle
            self.url = url
            self.navigationTarget = nil
            self.telemetryEventName = event
        }
        
        init(localizedTitle: String, navigationTarget: NavigationTarget, event: String? = nil) {
            self.localizedTitle = localizedTitle
            self.url = nil
            self.navigationTarget = navigationTarget
            self.telemetryEventName = event
        }
    }
    
    // MARK: Properties
    
    private let sectionCount = 1
    
    private let headerPath = IndexPath(row: 0, section: 0)
    private(set) var largeBannerContainerView: UIView! = UIView(frame: .zero)
    
    private var aboutLinks: [AboutLinkCellModel] {
        var links = [
            AboutLinkCellModel(localizedTitle: GDLocalizedString("settings.about.title.whats_new"), navigationTarget: .versionHistory),
            AboutLinkCellModel(localizedTitle: GDLocalizationUnnecessary("Privacy Policy"), url: AppContext.Links.privacyPolicyURL(for: LocalizationContext.currentAppLocale), event: "about.privacy_policy"),
            AboutLinkCellModel(localizedTitle: GDLocalizationUnnecessary("Services Agreement"), url: AppContext.Links.servicesAgreementURL(for: LocalizationContext.currentAppLocale), event: "about.services_agreement"),
            AboutLinkCellModel(localizedTitle: GDLocalizedString("settings.about.title.copyright"), navigationTarget: .thirdPartyNotices),
            AboutLinkCellModel(localizedTitle: GDLocalizationUnnecessary("YouTube Channel"), url: AppContext.Links.youtubeURL(for: LocalizationContext.currentAppLocale), event: "about.youtube_channel")
        ]
        
        if LocalizationContext.currentAppLocale == Locale.frFr {
            // If the app is localized in fr-FR, include a link to the France Accessibility landing page
            links.append(AboutLinkCellModel(localizedTitle: GDLocalizationUnnecessary("Accessibilité: partiellement conforme"), url: AppContext.Links.accessibilityFrance, event: "about.accessibility_fr_fr"))
        }
        
        return links
    }

    init() {
        super.init(style: .plain)
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder: NSCoder) {
        fatalError("Use init()")
    }
    
    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = GDLocalizedString("settings.section.about")

        tableView.registerCell(AboutHeaderCell.self)
        tableView.registerCell(CustomDisclosureTableViewCell.self)

        updateLargeBannerContainerViewFrame()
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.tintColor = Colors.Foreground.primary
        tableView.separatorColor = Colors.Background.tertiary
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateLargeBannerContainerViewFrame()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        GDATelemetry.trackScreenView("settings.about")
    }
    
    // MARK: UITableViewDelegate
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return aboutLinks.count + 1
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Handle the header cell separately
        if indexPath == headerPath {
            let cell: AboutHeaderCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
            cell.configure(versionText: GDLocalizedString("settings.version.about.version", AppContext.appVersion, AppContext.appBuild))
            return cell
        }
        
        // Make sure the index path is valid, otherwise return a default cell
        guard indexPath.section < sectionCount, indexPath.row - 1 < aboutLinks.count, indexPath.row > 0 else {
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        
        // Set the title for the cell
        let cell: CustomDisclosureTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
        cell.textLabel?.text = aboutLinks[indexPath.row - 1].localizedTitle
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.backgroundColor = Colors.Background.primary
        cell.accessibilityTraits = [.button]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        // Make sure the index path is valid, otherwise return a default cell
        guard indexPath.section < sectionCount, indexPath.row - 1 < aboutLinks.count, indexPath.row > 0 else {
            return
        }
        
        let model = aboutLinks[indexPath.row - 1]
        
        if let eventName = model.telemetryEventName {
            GDATelemetry.trackScreenView(eventName)
        }
        
        // If the cell navigates in-app, push the destination.
        if let navigationTarget = model.navigationTarget {
            switch navigationTarget {
            case .versionHistory:
                navigationController?.pushViewController(VersionHistoryTableViewController(), animated: true)
            case .thirdPartyNotices:
                let storyboard = UIStoryboard(name: "Settings", bundle: nil)
                let viewController = storyboard.instantiateViewController(withIdentifier: AboutApplicationViewController.thirdPartyNoticesStoryboardIdentifier)
                navigationController?.pushViewController(viewController, animated: true)
            }
            
            return
        }
        
        // Otherwise, if the cell has a URL, load it
        if let url = model.url {
            openURL(url: url)
        }

    }
    
    // MARK: Actions
    
    private func openURL(url: URL) {
        DDLogInfo("Opening URL: \(url)")
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredBarTintColor = Colors.Background.primary
        safariVC.preferredControlTintColor = Colors.Foreground.primary
        
        present(safariVC, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath == headerPath ? AboutApplicationViewController.aboutHeaderHeight : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath == headerPath ? AboutApplicationViewController.aboutHeaderHeight : 44
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

extension AboutApplicationViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerView.setHeight(height)
        updateLargeBannerContainerViewFrame()
        tableView.reloadData()
    }
    
}
