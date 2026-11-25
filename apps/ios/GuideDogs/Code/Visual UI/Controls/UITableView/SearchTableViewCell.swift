//
//  SearchTableViewCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

class SearchTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Colors.Background.primary
        textLabel?.textColor = Colors.Foreground.primary
        textLabel?.font = .preferredFont(forTextStyle: .body)
        textLabel?.adjustsFontForContentSizeCategory = true
        textLabel?.numberOfLines = 0
        imageView?.image = UIImage(named: "baseline_search_white_24pt")
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }
}
