//
//  TableViewHeaderFooterViewConfigurator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

/// This protocol can be used along with a `TableViewDelegate` to control how
/// a table's custom header views should be configured
protocol TableViewHeaderViewConfigurator: AnyObject {
    associatedtype TableViewHeader: UITableViewHeaderFooterView
    
    // MARK: `UITableViewHeaderFooterView`
    func configure(_ view: TableViewHeader, forDisplaying title: String)
}
