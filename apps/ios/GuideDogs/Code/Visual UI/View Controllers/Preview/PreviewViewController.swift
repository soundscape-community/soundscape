//
//  PreviewViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import Combine
import SwiftUI

class PreviewViewController: UIViewController {
    
    private let cardContainerView = UIView()
    let largeBannerContainerView: UIView! = UIView()
    let smallBannerContainerView: UIView! = UIView()
    private let virtualLocationView = UIView()
    private let activityIndicatorContainerView = UIView()
    private let tutorialContainerView = UIView()
    private let calloutPanelContainerView = UIView()

    private lazy var largeBannerContainerHeightConstraint = largeBannerContainerView.heightAnchor.constraint(equalToConstant: 0)
    private lazy var smallBannerContainerHeightConstraint = smallBannerContainerView.heightAnchor.constraint(equalToConstant: 0)
    private lazy var virtualLocationHeightConstraint = virtualLocationView.heightAnchor.constraint(equalToConstant: 270)
    private lazy var calloutPanelContainerHeightConstraint = calloutPanelContainerView.heightAnchor.constraint(equalToConstant: 141)
    private lazy var cardContainerViewHeightConstraint = cardContainerView.heightAnchor.constraint(equalToConstant: 214)

    private lazy var exitBarButtonItem = UIBarButtonItem(title: GDLocalizedString("general.alert.exit"), style: .plain,
                                                         target: self, action: #selector(onExitSelected))
    var roadToggleButton: UIBarButtonItem!
    
    // MARK: Properties
    
    private var virtualLocationViewController: VirtualLocationViewController?
    private weak var calloutButtonViewController: CalloutButtonPanelHostingViewController?
    private let loadingState = PreviewLoadingState()
    private var previewTutorialViewController: PreviewTutorialViewController?
    private var isActivatedAndStartedSubscriber: AnyCancellable?
    private var isStoppedAndDeactivatedSubscriber: AnyCancellable?
    private var userActionSubscriber: AnyCancellable?
    private var isActivatedAndStarted = false
    private var isRestarting = false
    private var isPresentingTutorialViewController = false
    private var initializationResult: LocationActionHandler.PreviewResult?
    var onDismissHandler: (() -> Void)?
    
    /// Holds the user action notification until the preview controller is active and started
    private var pendingUserActionNotification: Notification?
    
    var locationDetail: LocationDetail? {
        didSet {
            guard isViewLoaded else {
                return
            }
            
            // Save new state
            isRestarting = true
            
            // Deactivate the current behavior experience
            // Once deactivation is complete, the preview
            // experience will be re-started at the new location
            stop()
        }
    }
    
    private var behavior: PreviewBehavior<IntersectionDecisionPoint>? {
        didSet {
            guard oldValue?.id != behavior?.id else {
                return
            }
            
            virtualLocationViewController?.behavior = behavior
        }
    }
    
    // MARK: View Life Cycle
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(named: "Background Base")
        view.accessibilityIgnoresInvertColors = true
        title = GDLocalizedString("preview.title")
        navigationItem.leftBarButtonItem = exitBarButtonItem

        let background = UIImageView(image: UIImage(named: "Background"))
        background.contentMode = .scaleToFill
        for backgroundView in [background, activityIndicatorContainerView, tutorialContainerView] {
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(background)
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let search = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = GDLocalizedString("preview.search.label")
        configuration.image = UIImage(named: "search_white_24dp")
        configuration.imagePadding = 12
        configuration.titleAlignment = .leading
        configuration.baseBackgroundColor = Colors.Background.secondary
        configuration.baseForegroundColor = Colors.Foreground.primary
        search.configuration = configuration
        search.contentHorizontalAlignment = .leading
        search.accessibilityHint = GDLocalizedString("preview.search.accessibility_hint")
        search.addTarget(self, action: #selector(showBrowse), for: .touchUpInside)
        search.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let roundedContainers: [UIView] = [smallBannerContainerView, cardContainerView]
        for container in roundedContainers {
            container.layer.cornerRadius = 5
            container.clipsToBounds = true
        }

        let scroll = UIScrollView()
        scroll.bounces = false
        let panels = UIStackView(arrangedSubviews: [virtualLocationView, search, smallBannerContainerView, cardContainerView])
        panels.axis = .vertical
        panels.spacing = 8
        panels.isLayoutMarginsRelativeArrangement = true
        panels.directionalLayoutMargins = .init(top: 24, leading: 20, bottom: 24, trailing: 20)
        panels.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(panels)
        NSLayoutConstraint.activate([
            virtualLocationHeightConstraint,
            smallBannerContainerHeightConstraint,
            cardContainerViewHeightConstraint,
            panels.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            panels.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            panels.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            panels.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            panels.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        let stack = UIStackView(arrangedSubviews: [largeBannerContainerView, scroll, calloutPanelContainerView])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        calloutPanelContainerHeightConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            largeBannerContainerHeightConstraint,
            calloutPanelContainerHeightConstraint,
            calloutPanelContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 141),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])

        for overlay in [activityIndicatorContainerView, tutorialContainerView] {
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        tutorialContainerView.isHidden = true
    }

    static func navigation(for detail: LocationDetail, onDismiss: (() -> Void)? = nil) -> NavigationController {
        let preview = PreviewViewController()
        preview.locationDetail = detail
        preview.onDismissHandler = onDismiss
        let navigation = NavigationController(rootViewController: preview)
        navigation.modalPresentationStyle = .fullScreen
        return navigation
    }

    @objc private func showBrowse() {
        let search = SearchTableViewController()
        search.logContext = "preview"
        search.onDismissPreviewHandler = onDismissHandler
        navigationController?.pushViewController(search, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem

        configureCalloutButtonPanelView()

        let card = CardStateViewController()
        addChild(card)
        cardContainerView.addSubview(card.view)
        card.view.frame = cardContainerView.bounds
        card.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.didMove(toParent: self)
        
        // Initialize the road toggle button (this handles initial creation - all further updates are
        // handled by `configureToggleButton()`
        if SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads {
            roadToggleButton = UIBarButtonItem(image: UIImage(named: "preview_toggle_on"), style: .plain, target: self, action: #selector(onRoadToggleButtonTouchUpInside))
            roadToggleButton.accessibilityLabel = GDLocalizedString("preview.include_unnamed_roads.label.on")
            roadToggleButton.accessibilityHint = GDLocalizedString("preview.include_unnamed_roads.hint.on")
        } else {
            roadToggleButton = UIBarButtonItem(image: UIImage(named: "preview_toggle_off"), style: .plain, target: self, action: #selector(onRoadToggleButtonTouchUpInside))
            roadToggleButton.accessibilityLabel = GDLocalizedString("preview.include_unnamed_roads.label.off")
            roadToggleButton.accessibilityHint = GDLocalizedString("preview.include_unnamed_roads.hint.off")
        }
        
        // Transparent navigation bar
        navigationController?.navigationBar.configureAppearance(for: .transparentLightTitle)
        
        // Embed the `VirtualLocationViewController`
        let viewController = VirtualLocationViewController()
        viewController.behavior = self.behavior
        
        // Add child view controller
        self.add(viewController)
        self.virtualLocationView.addSubview(viewController.view)
        
        // Set layout for child view controller
        viewController.view.frame = self.virtualLocationView.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Ready to display
        viewController.didMove(toParent: self)
        
        // Save view controller
        virtualLocationViewController = viewController

        let activityIndicatorViewController = UIHostingController(rootView: PreviewActivityIndicatorView(state: loadingState))
        activityIndicatorViewController.view.backgroundColor = .clear
        addChild(activityIndicatorViewController)
        activityIndicatorContainerView.addSubview(activityIndicatorViewController.view)
        activityIndicatorViewController.view.frame = activityIndicatorContainerView.bounds
        activityIndicatorViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        activityIndicatorViewController.didMove(toParent: self)
        
        if FirstUseExperience.didComplete(.previewTutorial) == false {
            
            // Update state
            isPresentingTutorialViewController = true

            let tutorialViewController = PreviewTutorialViewController(delegate: self)
            addChild(tutorialViewController)
            tutorialContainerView.addSubview(tutorialViewController.view)
            tutorialViewController.view.frame = tutorialContainerView.bounds
            tutorialViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            tutorialViewController.didMove(toParent: self)
            previewTutorialViewController = tutorialViewController
            
            // Configure tutorial view on first launch
            configureTutorialView(isHidden: false)
        }
        
        // Fetch required data and start the preview
        // experience at the given location
        if let locationDetail = locationDetail {
            initializePreview(at: locationDetail)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateCalloutButtonTraits()
        
        // Transparent navigation bar
        navigationController?.navigationBar.configureAppearance(for: .transparentLightTitle)
        
        // Configure the toggle button view
        configureToggleButton()
        
        NSUserActivity(userAction: .streetPreview).becomeCurrent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Default navigation bar
        navigationController?.navigationBar.configureAppearance(for: .default)
    }
    
    deinit {
        // Stop updates
        isActivatedAndStartedSubscriber?.cancel()
        isStoppedAndDeactivatedSubscriber?.cancel()
        userActionSubscriber?.cancel()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateCalloutButtonTraits()
    }
    
    private func updateCalloutButtonTraits() {
        CalloutButtonPanelHostingViewController.updateTraitOverride(for: calloutButtonViewController, in: self)
    }

    private func configureCalloutButtonPanelView() {
        calloutButtonViewController = CalloutButtonPanelHostingViewController.embed(
            in: self,
            containerView: calloutPanelContainerView,
            logContext: "preview"
        )
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        
        if container is VirtualLocationViewController {
            virtualLocationHeightConstraint.constant = container.preferredContentSize.height
        }
        
        if container is CalloutButtonPanelHostingViewController {
            calloutPanelContainerHeightConstraint.constant = container.preferredContentSize.height
        }
        
        if container is CardStateViewController {
            cardContainerViewHeightConstraint.constant = container.preferredContentSize.height
        }
    }
    
    private func initializePreview(at locationDetail: LocationDetail) {
        // Stop updates
        isActivatedAndStartedSubscriber?.cancel()
        isStoppedAndDeactivatedSubscriber?.cancel()
        userActionSubscriber?.cancel()
        
        // Reset behavior
        behavior = nil
        
        // Reset values
        isActivatedAndStarted = false
        
        let progress = LocationActionHandler.preview(locationDetail: locationDetail) { [weak self] (result) in
            guard let `self` = self else {
                return
            }
            
            if self.isPresentingTutorialViewController {
                // Save result and process after the tutorial
                // has completed
                self.initializationResult = result
            } else {
                // Process result immediately
                self.onPreviewDidInitialize(result)
            }
        }
        
        // If we are downloading data, pass the progress object to the
        // view controller
        loadingState.phase = .activating(progress: progress)
        
        // Configure initial view
        configureActivityIndicatorView(isHidden: isActivatedAndStarted)
    }
    
    private func onPreviewDidInitialize(_ result: Result<PreviewBehavior<IntersectionDecisionPoint>, LocationActionError>) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            switch result {
            case .success(let behavior):
                // Save behavior
                self.behavior = behavior
                // Start the preview experience
                self.onPreviewDidInitialize(behavior)
            case .failure(let error):
                // Present the error alert and dismiss the current
                // view and return home
                let alert = LocationActionAlert.alert(for: error) { (_) in
                    self.dismiss(animated: true) { [weak self] in
                        self?.onDismissHandler?()
                    }
                }
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func onPreviewDidInitialize(_ behavior: PreviewBehavior<IntersectionDecisionPoint>) {
        // Listen for an event indicating that the
        // preview behavior has been activated and started
        isActivatedAndStartedSubscriber = behavior.isStartedSubject
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] (isStarted) in
                guard let `self` = self else {
                    return
                }
                
                // Save new value
                self.isActivatedAndStarted = isStarted
                
                // Update the state of the activity indicator view
                self.configureActivityIndicatorView(isHidden: isStarted)
                
                if isStarted {
                    self.continuePendingUserActionIfNeeded()
                }
            })
        
        // Listen for an event indicating that the
        // preview behavior has been stopped and deactivated
        isStoppedAndDeactivatedSubscriber = NotificationCenter.default
            .publisher(for: .behaviorDeactivated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                
                if let locationDetail = self.locationDetail, self.isRestarting {
                    // Reset value
                    self.isRestarting = false
                    
                    // Fetch required data and re-start the preview
                    // experience at the given location
                    self.initializePreview(at: locationDetail)
                } else {
                    // After the behavior has been deactivated,
                    // dismiss the view and return home
                    self.dismiss(animated: true) { [weak self] in
                        self?.onDismissHandler?()
                    }
                }
        }
        
        // Listen for an event indicating that the user has continued an action
        userActionSubscriber = NotificationCenter.default
            .publisher(for: .continueUserAction)
            .receive(on: RunLoop.main)
            .sink { [weak self] (notification) in
                guard let `self` = self else { return }
                
                if self.isActivatedAndStarted {
                    self.continueUserAction(notification)
                } else {
                    self.pendingUserActionNotification = notification
                }
            }
        
        start()
    }
    
    private func configureToggleButton() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            if SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads {
                self.roadToggleButton.image = UIImage(named: "preview_toggle_on")
                self.roadToggleButton.accessibilityLabel = GDLocalizedString("preview.include_unnamed_roads.label.on")
                self.roadToggleButton.accessibilityHint = GDLocalizedString("preview.include_unnamed_roads.hint.on")
            } else {
                self.roadToggleButton.image = UIImage(named: "preview_toggle_off")
                self.roadToggleButton.accessibilityLabel = GDLocalizedString("preview.include_unnamed_roads.label.off")
                self.roadToggleButton.accessibilityHint = GDLocalizedString("preview.include_unnamed_roads.hint.off")
            }
        }
    }
    
    private func configureContainerView(_ container: UIView, isHidden: Bool, navigationBarIsHidden: Bool, roadToggleItemIsHidden: Bool) {
        DispatchQueue.main.async {
            // Update the state of the activity indicator view
            UIView.transition(with: self.view, duration: 1.0, options: .transitionCrossDissolve, animations: { [weak self] in
                guard let `self` = self else {
                    return
                }
                
                // Hide sibling elements when a container view is presented
                container.accessibilityViewIsModal = isHidden == false
                
                // Show view
                container.isHidden = isHidden
                
                // Show or hide the road toggle button in the navigation item
                if roadToggleItemIsHidden {
                    self.navigationItem.remove(barButtonItem: self.roadToggleButton)
                } else {
                    self.navigationItem.setRightBarButton(self.roadToggleButton, animated: true)
                }
                
                // Update navigation bar
                self.navigationController?.setNavigationBarHidden(navigationBarIsHidden, animated: true)
            }, completion: { [weak self] (_) in
                guard let `self` = self else {
                    return
                }
                
                // Ensures that Voiceover is aware of new layout
                let argument = isHidden ? self.exitBarButtonItem : container
                UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: argument)
            })
        }
    }
    
    private func configureActivityIndicatorView(isHidden: Bool) {
        guard isPresentingTutorialViewController == false else {
            return
        }
        
        if isHidden == false, self.navigationController?.topViewController != self {
            // Pop to this view controller before displaying the activity
            // indicator view
            self.navigationController?.popToViewController(self, animated: true)
        }
        
        navigationController?.navigationBar.configureAppearance(for: isHidden ? .transparentLightTitle : .default)
        loadingState.isVisible = !isHidden
        configureContainerView(activityIndicatorContainerView, isHidden: isHidden, navigationBarIsHidden: false, roadToggleItemIsHidden: !isHidden)
    }
    
    private func configureTutorialView(isHidden: Bool) {
        configureContainerView(tutorialContainerView, isHidden: isHidden, navigationBarIsHidden: isHidden == false, roadToggleItemIsHidden: !isHidden)
    }
    
    // MARK: `IBAction`
    
    @objc func onExitSelected(_ sender: Any) {
        // Stop updates while exiting
        isActivatedAndStartedSubscriber?.cancel()
        
        // Reset value
        isRestarting = false
        
        // Disable exit button
        exitBarButtonItem.isEnabled = false
        
        stop()
    }
    
    @objc func onRoadToggleButtonTouchUpInside() {
        SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads.toggle()

        // Reconfigure the view
        configureToggleButton()
    }
    
    static func restart(from presenter: UIViewController, at detail: LocationDetail) {
        if let navigation = presenter.navigationController,
           let preview = navigation.viewControllers.first as? PreviewViewController {
            navigation.popToRootViewController(animated: true)
            preview.locationDetail = detail
            return
        }

        var controller = AppContext.rootViewController?.presentedViewController
        while let current = controller {
            if let navigation = current as? UINavigationController,
               let preview = navigation.viewControllers.first as? PreviewViewController {
                navigation.popToRootViewController(animated: true)
                preview.locationDetail = detail
                return
            }
            controller = current.presentedViewController
        }
    }
    
    // MARK: Preview
    
    private func start() {
        guard AppContext.shared.eventProcessor.activeBehavior.id != behavior?.id else {
            return
        }
        
        guard let behavior = behavior else {
            return
        }
        
        // Show the activity indicator view while activating
        // and starting the behavior
        configureActivityIndicatorView(isHidden: false)
        
        // Activate the preview behavior
        AppContext.shared.eventProcessor.activateCustom(behavior: behavior)
    }
    
    private func stop() {
        if let behavior = behavior {
            guard AppContext.shared.eventProcessor.activeBehavior.id == behavior.id else {
                return
            }
            
            // Do not display progress while deactivating
            loadingState.phase = .deactivating
            
            // Show the activity indicator view while stopping
            // and deactivating the behavior
            configureActivityIndicatorView(isHidden: false)
            
            // Deactivate the preview behavior
            AppContext.shared.eventProcessor.deactivateCustom()
        } else {
            // There is no behavior to deactivate (it might be initializing)
            // Dismiss the view and return home
            self.dismiss(animated: true) { [weak self] in
                self?.onDismissHandler?()
            }
        }
    }
    
    // MARK: User Actions
    
    private func continueUserAction(_ notification: Notification) {
        guard let userAction = notification.userInfo?[UserActionManager.Keys.userAction] as? UserAction else { return }
        
        GDLogAppInfo("Continuing user action: \(userAction.rawValue) (street preview)")
        
        if let action = CalloutButtonPanelAction(userAction: userAction) {
            calloutButtonViewController?.perform(action, sender: notification.object as AnyObject?)
            return
        }

        switch userAction {
        case .search:
            showBrowse()
        case .saveMarker:
            // Not supported in street preview
            break
        case .streetPreview:
            // Already in street preview
            break
        case .myLocation, .aroundMe, .aheadOfMe, .nearbyMarkers:
            break
        }
    }
    
    private func continuePendingUserActionIfNeeded() {
        guard let pendingUserActionNotification = pendingUserActionNotification else { return }
        continueUserAction(pendingUserActionNotification)
        self.pendingUserActionNotification = nil
    }
    
}

// MARK: - PreviewTutorialDelegate

extension PreviewViewController: PreviewTutorialDelegate {
    
    func previewTutorialDidComplete() {
        
        // Update state
        isPresentingTutorialViewController = false

        previewTutorialViewController?.willMove(toParent: nil)
        previewTutorialViewController?.view.removeFromSuperview()
        previewTutorialViewController?.removeFromParent()
        previewTutorialViewController = nil
        
        if let initializationResult = initializationResult {
            // Process result
            onPreviewDidInitialize(initializationResult)
            
            // Reset value
            self.initializationResult = nil
        }
        
        configureTutorialView(isHidden: true)
        configureActivityIndicatorView(isHidden: false)
    }
    
}

// MARK: - LargeBannerContainerView

extension PreviewViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerHeightConstraint.constant = height
    }
    
}

// MARK: - SmallBannerContainerView

extension PreviewViewController: SmallBannerContainerView {
    
    func setSmallBannerHeight(_ height: CGFloat) {
        smallBannerContainerHeightConstraint.constant = height
    }
    
}
