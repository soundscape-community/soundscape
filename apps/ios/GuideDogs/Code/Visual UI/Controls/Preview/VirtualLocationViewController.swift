//
//  VirtualLocationViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import Combine

class VirtualLocationViewController: UIViewController {
    
    enum State: Equatable {
        case orientation
        case edge(edge: RoadAdjacentDataView)
        case transition
        
        static func == (lhs: VirtualLocationViewController.State, rhs: VirtualLocationViewController.State) -> Bool {
            switch lhs {
            case .orientation:
                if case .orientation = rhs {
                    return true
                } else {
                    return false
                }
            case .edge(let lhsEdge):
                if case .edge(let rhsEdge) = rhs {
                    return lhsEdge == rhsEdge
                } else {
                    return false
                }
            case .transition:
                if case .transition = rhs {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    private let contentView = UIView()
    private lazy var contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 128)
    private let currentLocationLabel = UILabel()
    private let backLabel = UILabel()

    // MARK: Properties
    
    private var contentViewController: PreviewControlViewController?
    private var focusedEdgeSubscriber: AnyCancellable?
    private var isTransitioning = false
    private var focussedEdge: RoadAdjacentDataView?
    private var decisionPoint: IntersectionDecisionPoint?
    
    weak var behavior: PreviewBehavior<IntersectionDecisionPoint>? {
        didSet {
            guard oldValue?.id != behavior?.id else {
                return
            }
            
            // Stop updates from the current subscribter
            focusedEdgeSubscriber?.cancel()
            
            guard let behavior = behavior else {
                return
            }
            
            focusedEdgeSubscriber = behavior.currentlyFocussedRoad
                // Sends tuples of (currentlyFocussedRoad, isTransitioning, currentDecisionPoint)
                .combineLatest(behavior.isTransitioningSubject, behavior.currentDecisionPoint)
                // Make sure there is at least 0.5 sec between calls to configureView() so animations don't get messed up
                .throttle(for: 0.5, scheduler: RunLoop.main, latest: true)
                .sink(receiveValue: { [weak self] (newValue) in
                    guard let `self` = self else {
                        return
                    }
                    
                    // Save old values
                    let oldIsTransitioning = self.isTransitioning
                    
                    let (edge, isTransitioning, decisionPoint) = newValue
                    
                    // Save new values
                    self.isTransitioning = isTransitioning
                    self.focussedEdge = edge
                    self.decisionPoint = decisionPoint
                    
                    // If `isTransitioning` has changed, post a notification
                    // to ensure that Voiceover is aware of the new layout
                    self.configureView(postNotification: oldIsTransitioning != isTransitioning)
            })
        }
    }
    
    private var currentState: State {
        if isTransitioning {
            return .transition
        } else if let edge = focussedEdge {
            return .edge(edge: edge)
        } else {
            return .orientation
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: View Life Cycle
    
    override func loadView() {
        view = UIView()

        currentLocationLabel.numberOfLines = 0
        currentLocationLabel.font = .preferredFont(forTextStyle: .caption1)
        currentLocationLabel.textColor = .white
        currentLocationLabel.adjustsFontForContentSizeCategory = true

        let button = UIButton(type: .system)
        button.accessibilityLabel = GDLocalizedString("preview.go_back.title")
        button.accessibilityHint = GDLocalizedString("preview.go_back.accessibility_text")
        button.addTarget(self, action: #selector(onBackButtonTouchUpInside), for: .touchUpInside)
        backLabel.text = GDLocalizedString("preview.go_back.title")
        backLabel.textAlignment = .center
        backLabel.textColor = .white
        backLabel.numberOfLines = 0
        backLabel.font = .preferredFont(forTextStyle: .body)
        backLabel.adjustsFontForContentSizeCategory = true
        backLabel.isAccessibilityElement = false
        backLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(backLabel)

        let actions = UIStackView(arrangedSubviews: [button])
        actions.alignment = .center
        actions.axis = .vertical

        let stack = UIStackView(arrangedSubviews: [currentLocationLabel, contentView, actions])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(24, after: contentView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            contentViewHeightConstraint,
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            backLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            backLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4),
            backLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 8),
            backLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewController = PreviewControlViewController()
        
        // Add new child view controller
        // to the container view
        addChild(viewController)
        self.contentView.addSubview(viewController.view)
        
        // Set layout for `child.view`
        viewController.view.frame = self.contentView.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Ready to display
        viewController.didMove(toParent: self)
        
        // Ensure that Voiceover is aware of the new layout
        UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
        
        // Save reference to child view controller
        self.contentViewController = viewController
        self.contentViewController?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure initial view
        configureView()
    }
    
    deinit {
        // Stop updates
        focusedEdgeSubscriber?.cancel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update back label appearance
        backLabel.layer.cornerRadius = backLabel.bounds.size.height / 2.0
        backLabel.layer.masksToBounds = true
        backLabel.layer.borderColor = backLabel.textColor.cgColor
        backLabel.layer.borderWidth = 0.75
        
        // Update view height
        let width = preferredContentSize.width
        let height = UIView.preferredContentHeightCompressedHeight(for: view)
        
        preferredContentSize = CGSize(width: width, height: height)
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        
        if let container = container as? UIViewController, container == contentViewController {
            contentViewHeightConstraint.constant = container.preferredContentSize.height
        }
    }
    
    private func configureView(postNotification: Bool = false) {
        guard isViewLoaded else {
            return
        }
        
        self.startAnimation { [weak self] in
            guard let `self` = self else {
                return
            }
            
            // Configure the current location label
            if self.isTransitioning {
                // Approaching next decision point
                self.currentLocationLabel.text = GDLocalizedString("preview.approaching_intersection.label").uppercasedWithAppLocale()
            } else if let currentLocation = self.decisionPoint?.node.localizedName {
                // Display current location
                self.currentLocationLabel.text = GDLocalizedString("directions.at_poi", currentLocation).uppercasedWithAppLocale()
            } else {
                // Current location is unknown
                self.currentLocationLabel.text = GDLocalizedString("preview.current_intersection_unknown.label").uppercasedWithAppLocale()
            }
            
            // Configure content view controller
            self.contentViewController?.currentState = self.currentState
            
            if postNotification {
                self.view.layoutIfNeeded()
                // Ensure that Voiceover is aware of the new layout
                UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
            }
            
            self.view.layoutIfNeeded()
            
            self.stopAnimation()
        }
    }
    
    private func startAnimation(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25, animations: { [weak self] in
            guard let `self` = self else {
                return
            }
            
            self.contentView.alpha = 0
        }, completion: { (_) in
            completion()
        })
    }
    
    private func stopAnimation() {
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let `self` = self else {
                return
            }
            
            self.contentView.alpha = 1
        }
    }
    
    // MARK: `IBAction`
    
    @objc func onBackButtonTouchUpInside(_ sender: Any) {
        guard isTransitioning == false else {
            return
        }
        
        guard let behavior = self.behavior else {
            return
        }
        
        guard behavior.canGoToPrevious else {
            return
        }
        
        behavior.goToPrevious()
    }
    
}

extension VirtualLocationViewController: PreviewControlDelegate {
    
    func previewControl(_ viewController: PreviewControlViewController, didSelect edge: RoadAdjacentDataView?) {
        behavior?.select(edge)
    }
    
}
