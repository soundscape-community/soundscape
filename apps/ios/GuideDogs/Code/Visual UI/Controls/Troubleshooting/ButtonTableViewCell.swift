//
//  ButtonTableViewCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

class ButtonTableViewCell: UITableViewCell {
    static let reuseIdentifier = "ButtonTableViewCell"

    let button = RoundedSolidButton(type: .system)
    let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .callout)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.isAccessibilityElement = false
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            label.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: button.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -8)
        ])
        accessibilityElements = [button]
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.textAlignment = .center
    }
}
