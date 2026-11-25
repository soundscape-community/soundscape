//
//  ActivityIndicatorTableViewCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

class ActivityIndicatorTableViewCell: UITableViewCell {
    private let spinner = UIActivityIndicatorView(style: .medium)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Colors.Background.primary
        selectionStyle = .none
        let isOffline = reuseIdentifier == "OfflineTableViewCell"
        let label = UILabel()
        label.text = GDLocalizedString(isOffline ? "searching.offline" : "search.searching_with_punctuation")
        label.textColor = .white
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        spinner.color = .white
        spinner.startAnimating()
        spinner.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [spinner, label])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        spinner.startAnimating()
    }
}

func makePOILoadingOverlay() -> UIView {
    let overlay = UIView()
    overlay.backgroundColor = UIColor(named: "Background Base")?.withAlphaComponent(0.75)
    overlay.translatesAutoresizingMaskIntoConstraints = false
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.color = .white
    spinner.translatesAutoresizingMaskIntoConstraints = false
    overlay.addSubview(spinner)
    NSLayoutConstraint.activate([
        spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
    ])
    spinner.startAnimating()
    return overlay
}
