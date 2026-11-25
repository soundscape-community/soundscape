//
//  POITableViewCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

class POITableViewCell: UITableViewCell {
    enum ImageViewType {
        case marker, place, search, new, none

        var imageName: String? {
            switch self {
            case .marker: return "ic_markers_28px"
            case .place: return "ic_place_white"
            case .search: return "baseline_search_white_24pt"
            case .new: return "badge_new"
            case .none: return nil
            }
        }
    }

    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let detailLabel = UILabel()
    private let icon = UIImageView()
    private let iconContainer = UIView()

    var imageViewType: ImageViewType = .none {
        didSet {
            icon.image = imageViewType.imageName.flatMap { UIImage(named: $0) }
            iconContainer.isHidden = icon.image == nil
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Colors.Background.primary

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = Colors.Foreground.primary
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = UIColor(named: "Highlight Yellow")
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = UIColor(named: "Foreground 3")
        for label in [titleLabel, subtitleLabel, detailLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.highlightedTextColor = Colors.Background.primary
        }

        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isHidden = true
        iconContainer.addSubview(icon)
        let width = iconContainer.widthAnchor.constraint(equalToConstant: 28)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            width,
            iconContainer.heightAnchor.constraint(equalToConstant: 28),
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])

        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 2
        let row = UIStackView(arrangedSubviews: [iconContainer, labels])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }
}
