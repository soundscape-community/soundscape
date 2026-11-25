//
//  FilterTableViewHeaderView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

protocol FilterTableViewHeaderViewDelegate: AnyObject {
    var isEnabled: Bool { get }
    func didSelect(action: FilterTableViewHeaderView.Action)
}

class FilterTableViewHeaderView: UITableViewHeaderFooterView {
    
    enum Action: CaseIterable {
        case clear
        case set
        
        init?(localizedTitle: String) {
            guard let value = Action.allCases.first(where: { $0.localizedTitle == localizedTitle }) else {
                return nil
            }
            
            self = value
        }
        
        var localizedTitle: String {
            switch self {
            case .clear: return GDLocalizedString("filter.clear.capital")
            case .set: return GDLocalizedString("filter.set")
            }
        }
        
        var localizedAccessibilityHint: String {
            switch self {
            case .clear: return GDLocalizedString("filter.clear.hint")
            case .set: return GDLocalizedString("filter.double_tap_places_category")
            }
        }
    }
    
    // MARK: Properties
    
    weak var delegate: FilterTableViewHeaderViewDelegate?
    private var tapGestureRecognizer: UITapGestureRecognizer!
    
    let titleLabel = UILabel()
    let actionButton = UIButton(type: .system)
    
    // MARK: View Life Cycle
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let background = UIView()
        background.backgroundColor = Colors.Background.secondary
        backgroundView = background
        titleLabel.textColor = .white
        titleLabel.font = .preferredFont(forTextStyle: .callout)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        actionButton.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.titleLabel?.numberOfLines = 0
        actionButton.addTarget(self, action: #selector(onActionButtonTouchUpInside), for: .touchUpInside)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [titleLabel, actionButton])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        // Initialize tap gesture
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onActionButtonTouchUpInside))
        
        // If VoiceOver is running, add tap gesture
        if UIAccessibility.isVoiceOverRunning {
            self.addGestureRecognizer(tapGestureRecognizer)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAccessibilityVoiceOverStatusChanged), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Use init(reuseIdentifier:)")
    }

    // MARK: Notifications
    
    @objc private func onAccessibilityVoiceOverStatusChanged() {
        if UIAccessibility.isVoiceOverRunning {
            self.addGestureRecognizer(tapGestureRecognizer)
        } else {
            self.removeGestureRecognizer(tapGestureRecognizer)
        }
    }
    
    // MARK: Actions
    
    @objc func onActionButtonTouchUpInside() {
        guard let localizedTitle = actionButton.currentTitle else {
            return
        }
        
        guard let action = Action(localizedTitle: localizedTitle) else {
            return
        }
        
        delegate?.didSelect(action: action)
    }

}
