//
//  HelpPageFAQListTableViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

class HelpPageFAQListTableViewController: BaseTableViewController {
    private static let faqViewStoryboardIdentifier = "helpFAQPage"

    private var faqList: FAQListHelpPage!

    init() {
        super.init(style: .grouped)
    }

    @available(*, unavailable, message: "Use init()")
    required init?(coder: NSCoder) {
        fatalError("Use init()")
    }
    
    func loadContent(_ content: FAQListHelpPage) {
        faqList = content
        title = content.title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerCell(CustomDisclosureTableViewCell.self)
        tableView.tintColor = Colors.Foreground.primary
        tableView.separatorColor = Colors.Background.tertiary
    }

    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return faqList.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < faqList.sections.count else {
            return 0
        }
        
        return faqList.sections[section].faqs.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < faqList.sections.count else {
            return nil
        }
        
        return faqList.sections[section].heading
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: CustomDisclosureTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
        
        guard indexPath.section < faqList.sections.count, indexPath.row < faqList.sections[indexPath.section].faqs.count else {
            return cell
        }
        
        cell.textLabel?.text = faqList.sections[indexPath.section].faqs[indexPath.row].question
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.backgroundColor = Colors.Background.primary
        cell.accessibilityTraits = [.button]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section < faqList.sections.count, indexPath.row < faqList.sections[indexPath.section].faqs.count else {
            return
        }

        let storyboard = UIStoryboard(name: "Help", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: HelpPageFAQListTableViewController.faqViewStoryboardIdentifier)

        guard let faqViewController = viewController as? HelpPageFAQViewController else {
            return
        }

        faqViewController.faq = faqList.sections[indexPath.section].faqs[indexPath.row]
        navigationController?.pushViewController(faqViewController, animated: true)
    }

}
