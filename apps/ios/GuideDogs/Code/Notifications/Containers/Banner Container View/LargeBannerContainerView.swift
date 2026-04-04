//
//  LargeBannerContainerView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

protocol LargeBannerContainerView {
    var largeBannerContainerView: UIView! { get }
    func setLargeBannerHeight(_ height: CGFloat)
}

protocol LargeBannerTableHeaderContainerView: LargeBannerContainerView where Self: UITableViewController {}

extension LargeBannerTableHeaderContainerView {
    func syncLargeBannerTableHeaderFrame() {
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

    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerView.setHeight(height)
        syncLargeBannerTableHeaderFrame()
        tableView.reloadData()
    }
}
