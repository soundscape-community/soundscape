//
//  CalloutButtonViewController.swift
//  Soundscape - Accessible Circular Button Redesign
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import UIKit
import NVActivityIndicatorView

extension NSNotification.Name {
    static let didToggleLocate = Notification.Name("DidToggleLocate")
    static let didToggleOrientate = Notification.Name("DidToggleOrientate")
    static let didToggleLookAhead = Notification.Name("DidToggleLookAhead")
    static let didToggleMarkedPoints = Notification.Name("DidToggleMarkedPoints")
}

class CalloutButtonPanelViewController: UIViewController {
    
    // MARK: Properties
    
    // Original IBOutlets - will be hidden/removed
    @IBOutlet var headerLabel: UILabel!
    @IBOutlet var buttonLabels: [UILabel]!
    @IBOutlet weak var locateContainer: UIView!
    @IBOutlet weak var orientContainer: UIView!
    @IBOutlet weak var exploreContainer: UIView!
    @IBOutlet weak var markedPointsContainer: UIView!
    @IBOutlet weak var locateImageView: UIImageView!
    @IBOutlet weak var orientateImageView: UIImageView!
    @IBOutlet weak var exploreImageView: UIImageView!
    @IBOutlet weak var markedPointImageView: UIImageView!
    @IBOutlet weak var locateAnimation: NVActivityIndicatorView!
    @IBOutlet weak var orientateAnimation: NVActivityIndicatorView!
    @IBOutlet weak var exploreAnimation: NVActivityIndicatorView!
    @IBOutlet weak var markedPointsAnimation: NVActivityIndicatorView!
    
    // New circular buttons
    private var locateButton: AccessibleCircularButton!
    private var orientButton: AccessibleCircularButton!
    private var exploreButton: AccessibleCircularButton!
    private var markedPointsButton: AccessibleCircularButton!
    
    private var newHeaderLabel: UILabel!
    
    var logContext: String?
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide all original storyboard elements
        [locateContainer, orientContainer, exploreContainer, markedPointsContainer].forEach {
            $0?.isHidden = true
        }
        headerLabel?.isHidden = true
        buttonLabels?.forEach { $0.isHidden = true }
        
        // Setup new accessible layout
        setupAccessibleLayout()
        setupNotifications()
    }
    
    private func setupAccessibleLayout() {
        view.backgroundColor = .systemBackground
        
        // New Header
        newHeaderLabel = UILabel()
        newHeaderLabel.text = GDLocalizedString("callouts.panel.title").uppercasedWithAppLocale()
        newHeaderLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        newHeaderLabel.textAlignment = .center
        newHeaderLabel.adjustsFontForContentSizeCategory = true
        newHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newHeaderLabel)
        
        // Calculate responsive button size
        let screenWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let buttonSize: CGFloat = min(160, (screenWidth - 60) / 2) // Large touch targets
        let spacing: CGFloat = 20
        
        // Create circular buttons
        locateButton = AccessibleCircularButton(
            size: buttonSize,
            imageName: "location.fill",
            title: GDLocalizedString("directions.my_location"),
            accessibilityHint: GDLocalizedString("ui.action_button.my_location.acc_hint")
        )
        locateButton.addTarget(self, action: #selector(onLocateTouchUpInside), for: .touchUpInside)
        locateButton.accessibilityIdentifier = "btn.mylocation"
        
        orientButton = AccessibleCircularButton(
            size: buttonSize,
            imageName: "arrow.triangle.2.circlepath",
            title: GDLocalizedString("help.orient.page_title"),
            accessibilityHint: GDLocalizedString("ui.action_button.around_me.acc_hint")
        )
        orientButton.addTarget(self, action: #selector(onOrientateTouchUpInside), for: .touchUpInside)
        orientButton.accessibilityIdentifier = "btn.aroundme"
        
        exploreButton = AccessibleCircularButton(
            size: buttonSize,
            imageName: "arrow.up.circle.fill",
            title: GDLocalizedString("help.explore.page_title"),
            accessibilityHint: GDLocalizedString("ui.action_button.ahead_of_me.acc_hint")
        )
        exploreButton.addTarget(self, action: #selector(onLookAheadTouchUpInside), for: .touchUpInside)
        exploreButton.accessibilityIdentifier = "btn.aheadofme"
        
        markedPointsButton = AccessibleCircularButton(
            size: buttonSize,
            imageName: "mappin.circle.fill",
            title: GDLocalizedString("callouts.nearby_markers"),
            accessibilityHint: GDLocalizedString("ui.action_button.nearby_markers.acc_hint")
        )
        markedPointsButton.addTarget(self, action: #selector(onMarkedPointsTouchUpInside), for: .touchUpInside)
        markedPointsButton.accessibilityIdentifier = "btn.nearbymarkers"
        
        // Add buttons to view
        [locateButton, orientButton, exploreButton, markedPointsButton].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0!)
        }
        
        // Layout in 2x2 grid
        NSLayoutConstraint.activate([
            // Header
            newHeaderLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            newHeaderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newHeaderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            newHeaderLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            
            // Top row
            locateButton.topAnchor.constraint(equalTo: newHeaderLabel.bottomAnchor, constant: 24),
            locateButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: spacing),
            locateButton.widthAnchor.constraint(equalToConstant: buttonSize),
            locateButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            orientButton.topAnchor.constraint(equalTo: locateButton.topAnchor),
            orientButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -spacing),
            orientButton.widthAnchor.constraint(equalToConstant: buttonSize),
            orientButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            // Bottom row
            exploreButton.topAnchor.constraint(equalTo: locateButton.bottomAnchor, constant: spacing),
            exploreButton.leadingAnchor.constraint(equalTo: locateButton.leadingAnchor),
            exploreButton.widthAnchor.constraint(equalToConstant: buttonSize),
            exploreButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            markedPointsButton.topAnchor.constraint(equalTo: exploreButton.topAnchor),
            markedPointsButton.trailingAnchor.constraint(equalTo: orientButton.trailingAnchor),
            markedPointsButton.widthAnchor.constraint(equalToConstant: buttonSize),
            markedPointsButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            // Bottom constraint
            markedPointsButton.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleLocateNotification), name: .didToggleLocate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleOrientateNotification), name: .didToggleOrientate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleLookAheadNotification), name: .didToggleLookAhead, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleMarkedPointsNotification), name: .didToggleMarkedPoints, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update preferred content size
        let width = view.bounds.width
        let height = view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        preferredContentSize = CGSize(width: width, height: max(height, 420))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Set accessibility elements order
        view.accessibilityElements = [locateButton, orientButton, exploreButton, markedPointsButton]
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Buttons auto-adjust with Dynamic Type
    }
    
    // MARK: Actions
    
    @IBAction @objc private func onLocateTouchUpInside(_ sender: AnyObject? = nil) {
        locateButton?.showLoadingAnimation()
        
        let completion: (Bool) -> Void = { [weak self] _ in
            self?.locateButton?.hideLoadingAnimation()
        }
        
        let event: Event
        if let preview = AppContext.shared.eventProcessor.activeBehavior as? PreviewBehavior<IntersectionDecisionPoint> {
            event = PreviewMyLocationEvent(current: preview.currentDecisionPoint.value, completionHandler: completion)
        } else {
            event = ExplorationModeToggled(.locate, sender: sender, logContext: logContext, completion: completion)
        }
        
        AppContext.process(event)
    }
    
    @IBAction @objc private func onOrientateTouchUpInside(_ sender: AnyObject? = nil) {
        orientButton?.showLoadingAnimation()
        
        AppContext.process(ExplorationModeToggled(.aroundMe, sender: sender, logContext: logContext) { [weak self] _ in
            self?.orientButton?.hideLoadingAnimation()
        })
    }
    
    @IBAction @objc private func onLookAheadTouchUpInside(_ sender: AnyObject? = nil) {
        exploreButton?.showLoadingAnimation()
        
        AppContext.process(ExplorationModeToggled(.aheadOfMe, sender: sender, logContext: logContext) { [weak self] _ in
            self?.exploreButton?.hideLoadingAnimation()
        })
    }
    
    @IBAction @objc private func onMarkedPointsTouchUpInside(_ sender: AnyObject? = nil) {
        markedPointsButton?.showLoadingAnimation()
        
        AppContext.process(ExplorationModeToggled(.nearbyMarkers, sender: sender, logContext: logContext) { [weak self] _ in
            self?.markedPointsButton?.hideLoadingAnimation()
        })
    }
    
    // MARK: Notifications
    
    @objc func handleDidToggleLocateNotification(_ notification: Notification) {
        onLocateTouchUpInside(notification.object as AnyObject?)
    }
    
    @objc func handleDidToggleOrientateNotification(_ notification: Notification) {
        onOrientateTouchUpInside(notification.object as AnyObject?)
    }
    
    @objc func handleDidToggleLookAheadNotification(_ notification: Notification) {
        onLookAheadTouchUpInside(notification.object as AnyObject?)
    }
    
    @objc func handleDidToggleMarkedPointsNotification(_ notification: Notification) {
        onMarkedPointsTouchUpInside(notification.object as AnyObject?)
    }
}

// MARK: - Accessible Circular Button

class AccessibleCircularButton: UIControl {
    
    private let loadingIndicator: NVActivityIndicatorView
    private let iconImageView: UIImageView
    private let titleLabel: UILabel
    private let buttonSize: CGFloat
    
    init(size: CGFloat, imageName: String, title: String, accessibilityHint: String) {
        self.buttonSize = size
        
        // Create loading indicator
        loadingIndicator = NVActivityIndicatorView(
            frame: .zero,
            type: .circleStrokeSpin,
            color: .white,
            padding: nil
        )
        
        // Create icon
        iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        
        // Create title label
        titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        
        super.init(frame: .zero)
        
        // Configure button appearance
        backgroundColor = .systemBlue
        layer.cornerRadius = size / 2
        clipsToBounds = true
        
        // Add shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.2
        
        // Set SF Symbol icon
        let config = UIImage.SymbolConfiguration(pointSize: size * 0.25, weight: .semibold)
        iconImageView.image = UIImage(systemName: imageName, withConfiguration: config)
        
        titleLabel.text = title
        
        // Add subviews
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(loadingIndicator)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -size * 0.12),
            iconImageView.widthAnchor.constraint(equalToConstant: size * 0.3),
            iconImageView.heightAnchor.constraint(equalToConstant: size * 0.3),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 50),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        loadingIndicator.isHidden = true
        
        // Accessibility
        self.isAccessibilityElement = true
        self.accessibilityLabel = title
        self.accessibilityHint = accessibilityHint
        self.accessibilityTraits = .button
        
        // Touch handling
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func touchDown() {
        // Visual and haptic feedback
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.alpha = 0.8
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
    
    func showLoadingAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.iconImageView.isHidden = true
            self.titleLabel.isHidden = true
            self.loadingIndicator.isHidden = false
            self.loadingIndicator.startAnimating()
            self.accessibilityValue = "Loading"
        }
    }
    
    func hideLoadingAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.isHidden = true
            self.iconImageView.isHidden = false
            self.titleLabel.isHidden = false
            self.accessibilityValue = nil
        }
    }
    
    // Increase touch area for accessibility (44x44 minimum)
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let expandedBounds = bounds.insetBy(dx: -10, dy: -10)
        return expandedBounds.contains(point)
    }
}
