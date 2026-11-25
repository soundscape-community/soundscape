//
//  BannerViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

class BannerViewController: UIViewController {
    
    // MARK: Properties
    
    weak var delegate: BannerViewControllerDelegate?
    
    weak var contentView: UIView!
    
    // MARK: Actions
    
    @objc func onTouchUpInside() {
        
        delegate?.didSelect(self)
    }
    
}

class ConnectivityBannerViewController: BannerViewController {
    private let message: String
    private let background: UIColor
    private let opensHelp: Bool

    init(message: String, isOnline: Bool = false, opensHelp: Bool = false) {
        self.message = GDLocalizedString(message)
        self.background = isOnline
            ? UIColor(red: 0.221, green: 0.963, blue: 0.538, alpha: 1)
            : UIColor(red: 1, green: 0.933, blue: 0.349, alpha: 1)
        self.opensHelp = opensHelp
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(message:isOnline:opensHelp:)")
    }

    override func loadView() {
        let content = UIView()
        content.backgroundColor = background
        view = content
        contentView = content

        let label = UILabel()
        label.text = message
        label.textColor = UIColor(red: 0.129, green: 0.133, blue: 0.201, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])

        if opensHelp {
            label.isAccessibilityElement = false
            let button = UIButton(type: .system)
            button.accessibilityLabel = message
            button.addTarget(self, action: #selector(onTouchUpInside), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: content.topAnchor),
                button.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                button.bottomAnchor.constraint(equalTo: content.bottomAnchor)
            ])
        }
    }
}
