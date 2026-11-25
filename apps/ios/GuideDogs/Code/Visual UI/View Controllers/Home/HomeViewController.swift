//
//  HomeViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import CoreLocation
import CoreMotion
import MessageUI
import CocoaLumberjackSwift
import Combine
import SwiftUI

extension Notification.Name {
    static let homeViewControllerDidLoad = Notification.Name("HomeViewControllerDidLoad")
}

class HomeViewController: UIViewController, BannerHosting {
    
    private let layout = HomeLayout()
    private lazy var hosting = HomeHostingController(rootView: HomeView(layout: layout))
    var bannerHostingController: UIViewController { hosting }
    var largeBannerContainerView: UIView! { layout.largeBanner }
    var smallBannerContainerView: UIView! { layout.smallBanner }

    fileprivate var lastLocation: CLLocation?
    
    // New feature view
    
    private var didSignalHomeReady = false
    private var canShowLaunchActivities = false
    fileprivate var didCheckForNewFeatures = false
    
    private var sleepBarButton: UIBarButtonItem?
    var shouldFocusOnBeacon: Bool = false
    
    lazy var externalGPSBarButtonItem: UIBarButtonItem = {
        let icon = UIBarButtonItem(image: UIImage(named: "ic_settings_input_antenna_white"),
                               style: .plain,
                               target: nil,
                               action: nil)
        icon.accessibilityLabel = GDLocalizedString("bar_icon.external_GPS.acc_label")
        return icon
    }()
    
    private var searchController: UISearchController?
    
    // Experiences
    
    var cardViewController: CardStateViewController?
    var experienceDidStartObserver: NSObjectProtocol?
    var experienceDidFailToDownloadObserver: NSObjectProtocol?
    var listeners: [AnyCancellable] = []
    
    // Callout Button Panel
    
    private weak var calloutButtonViewController: CalloutButtonPanelHostingViewController?
    
    // MARK: View Life Cycle
    
    deinit {
        if let token = experienceDidStartObserver {
            NotificationCenter.default.removeObserver(token)
        }
        
        if let token = experienceDidFailToDownloadObserver {
            NotificationCenter.default.removeObserver(token)
        }
        
        listeners.cancelAndRemoveAll()
        
        DDLogDebug("\(String(describing: type(of: self))) deinitialized")
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(named: "Background Base")
        view.accessibilityIgnoresInvertColors = true
        extendedLayoutIncludesOpaqueBars = true

        add(hosting) { content in
            [
                content.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                content.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                content.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let menu = UIBarButtonItem(image: UIImage(named: "menu"), style: .plain,
                                   target: self, action: #selector(onMenuTouchUpInside))
        menu.accessibilityLabel = GDLocalizedString("ui.menu")
        menu.accessibilityHint = GDLocalizedString("ui.menu.hint")
        navigationItem.leftBarButtonItem = menu

        let sleep = UIBarButtonItem(image: UIImage(named: "sleep_icon"), style: .plain,
                                    target: self, action: #selector(onSleepTouchUpInside))
        sleep.accessibilityLabel = GDLocalizedString("sleep.sleep")
        sleep.accessibilityHint = GDLocalizedString("sleep.sleep.acc_hint")
        navigationItem.rightBarButtonItem = sleep
        sleepBarButton = sleep

        layout.showCurrentLocation = { [weak self] in self?.showCurrentLocation() }
        layout.saveCurrentLocation = { [weak self] in self?.saveCurrentLocation() }

        let card = CardStateViewController()
        cardViewController = card
        embed(card, in: layout.card)

        // Initialize the search controller
        self.searchController = UISearchController(delegate: self)
        self.searchController?.delegate = self
        self.searchController?.searchBar.searchTextField.overrideUserInterfaceStyle = .light
        self.searchController?.searchBar.searchTextField.accessibilityIdentifier = GDLocalizationUnnecessary("searchbar.home")
        
        // Add search controller to navigation bar
        configureSearchAndBrowseView()
        self.navigationItem.hidesSearchBarWhenScrolling = false

        // Don't allow ios 26 to move the search to the bottom.
        if #available(iOS 26.0, *) {
            self.navigationItem.searchBarPlacementAllowsToolbarIntegration = false
        }
        
        // Search results will be displayed modally
        // Use this view controller to define presentation context
        self.definesPresentationContext = true
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        configureNavigationBarButtonContrast()

        configureCalloutButtonPanelView()
        
        // Subscribe to notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleLocationUpdatedNotification), name: Notification.Name.locationUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.continueUserAction), name: Notification.Name.continueUserAction, object: nil)
        
        AppContext.shared.remoteCommandManager.delegate = self
        
        experienceDidStartObserver = NotificationCenter.default.addObserver(forName: Notification.Name.processedActivityDeepLink, object: nil, queue: OperationQueue.main, using: { [weak self] (_) in
            self?.showOrRefreshExperiences()
        })
        
        experienceDidFailToDownloadObserver = NotificationCenter.default.addObserver(forName: Notification.Name.activityDownloadDidFail, object: nil, queue: OperationQueue.main, using: { [weak self] (_) in
            let alert = UIAlertController(title: GDLocalizedString("behavior.experiences.download_failed.title"),
                                          message: GDLocalizedString("behavior.experiences.download_failed.error"),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .cancel, handler: nil))
            self?.present(alert, animated: true, completion: nil)
        })
        
        listeners.append(NotificationCenter.default.publisher(for: .behaviorActivated).receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] _ in
            self?.configureSearchAndBrowseView()
        }))
        
        listeners.append(NotificationCenter.default.publisher(for: .behaviorDeactivated).receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] _ in
            self?.configureSearchAndBrowseView()
        }))
        
        listeners.append(NotificationCenter.default.publisher(for: .didTryActivityUpdate).receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] notification in
            guard let `self` = self else {
                return
            }
            
            guard let userInfo = notification.userInfo else {
                return
            }
            
            guard let updatesAvailable = userInfo[AuthoredActivityLoader.Keys.updateAvailable] as? Bool else {
                return
            }
            
            guard let success = userInfo[AuthoredActivityLoader.Keys.updateSuccess] as? Bool else {
                return
            }
            
            let alert: UIAlertController
            
            if success {
                alert = UIAlertController.activityDidUpdate()
            } else if !updatesAvailable {
                alert = UIAlertController.activityUpdateUnavailable()
            } else {
                alert = UIAlertController.activityDidFailToUpdate()
            }
            
            self.present(alert, animated: true)
        }))

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateCalloutButtonTraits()
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        // Transparent navigation bar
        navigationController?.navigationBar.configureAppearance(for: .transparentLightTitle)
        configureNavigationBarButtonContrast()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAppWillEnterForeground(_:)), name: Notification.Name.appWillEnterForeground, object: nil)
        
        let hasLocationPermission = checkPermissions()
        canShowLaunchActivities = hasLocationPermission
            && (UIDeviceManager.isSimulator || CMMotionActivityManager.authorizationStatus() == .authorized)

        guard hasLocationPermission else {
            // Prevents edge case of New Feature Feature displaying after fixing location services
            // permissions on first launch (caused because iOS kills the app if you change the Motion
            // & Fitness setting in the Settings app).
            if AppContext.shared.isFirstLaunch {
                SettingsContext.shared.newFeaturesLastDisplayedVersion = AppContext.appVersion
                didCheckForNewFeatures = true
            }
            
            return
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !didSignalHomeReady {
            didSignalHomeReady = true
            NotificationCenter.default.post(name: .appDidInitialize, object: self)
            NotificationCenter.default.post(name: .homeViewControllerDidLoad, object: self)
        }
        
        if AppNavigationModel.shared.shouldFocusOnBeacon {
            AppNavigationModel.shared.shouldFocusOnBeacon = false
            shouldFocusOnBeacon = true
        }
        if shouldFocusOnBeacon, UIAccessibility.isVoiceOverRunning, let vc = cardViewController?.currentVC as? BeaconViewHostingController {
            GDLogAppInfo("Focusing VoiceOver on the beacon UI")
            UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: vc.view)
            shouldFocusOnBeacon = false
        }
        
        guard canShowLaunchActivities, !didCheckForNewFeatures else {
            return
        }
        
        if AppContext.shared.newFeatures.shouldShowNewFeatures() {
            AppNavigationModel.shared.newFeatures.wrappedValue = true
        } else if presentedViewController == nil && AppNavigationModel.shared.coordinator.path.isEmpty {
            LaunchActivityCoordinator.coordinateActivitiesOnAppLaunch(from: self)
        }
        didCheckForNewFeatures = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Default navigation bar
        navigationController?.navigationBar.configureAppearance(for: .default)
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name.appWillEnterForeground, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateCalloutButtonTraits()
        configureSearchAndBrowseView()
    }
    
    private func updateCalloutButtonTraits() {
        CalloutButtonPanelHostingViewController.updateTraitOverride(for: calloutButtonViewController, in: hosting)
    }
    
    fileprivate func updatePanelSize(_ container: UIContentContainer) {
        
        if container is CalloutButtonPanelHostingViewController {
            layout.calloutHeight = container.preferredContentSize.height
        }
        
        if container is CardStateViewController {
            layout.cardHeight = container.preferredContentSize.height
        }
    }
    
    private func configureSearchAndBrowseView() {
        let showsBrowse = !(AppContext.shared.eventProcessor.activeBehavior is GuidedTour)
        navigationItem.searchController = showsBrowse ? searchController : nil
        layout.showsBrowse = showsBrowse
    }

    private func configureNavigationBarButtonContrast() {
        let foregroundColor = UINavigationBar.Style.transparentLightTitle.foregroundColor

        navigationItem.leftBarButtonItem?.configureSoundscapeNavigationButton(foregroundColor: foregroundColor)
        navigationItem.rightBarButtonItem?.configureSoundscapeNavigationButton(foregroundColor: foregroundColor)
        navigationItem.leftBarButtonItems?.forEach { $0.configureSoundscapeNavigationButton(foregroundColor: foregroundColor) }
        navigationItem.rightBarButtonItems?.forEach { $0.configureSoundscapeNavigationButton(foregroundColor: foregroundColor) }
    }

    private func configureCalloutButtonPanelView() {
        calloutButtonViewController = CalloutButtonPanelHostingViewController.embed(
            in: hosting,
            containerView: layout.callouts,
            logContext: telemetryContext
        )
    }

    private func showOrRefreshExperiences() {
        let open = {
            let navigation = AppNavigationModel.shared
            navigation.returnHome()
            navigation.open(.recreation)
        }
        if let menu = presentedViewController as? MenuViewController {
            menu.dismiss(animated: true, completion: open)
        } else if let navigationController, navigationController.topViewController !== self {
            CATransaction.begin()
            CATransaction.setCompletionBlock(open)
            navigationController.popToViewController(self, animated: true)
            CATransaction.commit()
        } else {
            open()
        }
    }

    @discardableResult
    func checkPermissions() -> Bool {
        let geolocationManager = AppContext.shared.geolocationManager

        guard geolocationManager.coreLocationServicesEnabled,
              geolocationManager.coreLocationAuthorizationStatus == .fullAccuracyLocationAuthorized else {
            showPermission(.location)
            return false
        }

        MotionActivityContext.requestAuthorization { [weak self] (authorized, _) in
            guard let self = self else { return }
            if !authorized && !UIDeviceManager.isSimulator {
                // While Motion & Fitness is not authorized, disable callouts
                if SettingsContext.shared.automaticCalloutsEnabled {
                    MotionActivityContext.motionFitnessDidToggleCallouts = true
                    AppContext.process(ToggleAutoCalloutsEvent(playSound: false))
                }
                
                self.showPermission(.motion)
            } else {
                // If necessary, turn callouts back on
                if MotionActivityContext.motionFitnessDidToggleCallouts {
                    MotionActivityContext.motionFitnessDidToggleCallouts = false
                    AppContext.process(ToggleAutoCalloutsEvent(playSound: false))
                }
            }
        }
        
        return true
    }
    
    // MARK: Navigation

    private func embed(_ child: UIViewController, in container: UIView) {
        hosting.addChild(child)
        let content = child.view!
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        child.didMove(toParent: hosting)
    }

    private func showPermission(_ service: PermissionRoute) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.navigationController?.topViewController === self else { return }
            let navigation = AppNavigationModel.shared
            guard navigation.coordinator.path.isEmpty, self.viewIfLoaded?.window != nil else { return }
            navigation.open(.permission(service))
        }
    }

    private func showCurrentLocation() {
        guard let location = AppContext.shared.geolocationManager.location else {
            present(ErrorAlerts.buildLocationAlert(), animated: true)
            return
        }
        showLocationDetail(LocationDetail(location: location, telemetryContext: "current_location"))
    }

    private func saveCurrentLocation() {
        guard !layout.isSavingCurrentLocation else { return }
        guard let location = AppContext.shared.geolocationManager.location else {
            present(ErrorAlerts.buildLocationAlert(), animated: true)
            return
        }

        layout.isSavingCurrentLocation = true
        let detail = LocationDetail(location: location, telemetryContext: "current_location")
        LocationDetail.fetchNameAndAddressIfNeeded(for: detail) { [weak self] detail in
            DispatchQueue.main.async {
                guard let self else { return }
                self.layout.isSavingCurrentLocation = false
                let navigation = AppNavigationModel.shared
                guard self.navigationController?.topViewController === self, navigation.coordinator.path.isEmpty else { return }
                let config = EditMarkerConfig(detail: detail,
                                              route: nil,
                                              context: "current_location",
                                              addOrUpdateAction: .popViewController,
                                              deleteAction: .popViewController,
                                              leftBarButtonItemIsHidden: false)
                navigation.openEditor(MarkerEditViewRepresentable(config: config))
            }
        }
    }

    private func showLocationDetail(_ detail: LocationDetail) {
        AppNavigationModel.shared.showLocation(detail)
    }

    private func showPreview(_ detail: LocationDetail) {
        present(PreviewViewController.navigation(for: detail), animated: true)
    }


}

// MARK: UIViewControllerTransitioningDelegate

// This delegate is only used for animating the home screen menu in and off of the screen. This is not used for any of the other segues in the app.
extension HomeViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard presented is MenuViewController else {
            return nil
        }
        
        return MenuAnimator(.open)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let dismissed = dismissed as? MenuViewController else {
            return nil
        }
        
        return MenuAnimator(.close) { [weak self] finished in
            guard finished else { return }
            self?.layout.openMenuDestination(dismissed.selected)
        }
    }
}

// MARK: Actions

extension HomeViewController {
    
    @objc func onMenuTouchUpInside() {
        // Construct the menu and present it
        let vc = MenuViewController()
        vc.transitioningDelegate = self
        vc.modalPresentationStyle = .custom
        
        present(vc, animated: true, completion: nil)
    }
    
    @objc func onSleepTouchUpInside () {
        let controller = StandbyViewController()
        controller.delegate = self
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .crossDissolve
        present(controller, animated: true)
    }

}

// MARK: Notifications

extension HomeViewController {
    
    @objc func handleAppWillEnterForeground(_ notification: Notification) {
        checkPermissions()
    }
    
    @objc func handleLocationUpdatedNotification(_ notification: Notification) {
        guard let location = notification.userInfo?[SpatialDataContext.Keys.location] as? CLLocation else {
            return
        }
        
        lastLocation = location
    }

    func performCalloutButtonAction(_ action: CalloutButtonPanelAction, sender: AnyObject? = nil) {
        calloutButtonViewController?.perform(action, sender: sender)
    }
    
    @objc private func continueUserAction(_ notification: Notification) {
        guard !AppContext.shared.isStreetPreviewing else {
            // `PreviewViewController` will handle the user action
            return
        }
        
        guard let userAction = notification.userInfo?[UserActionManager.Keys.userAction] as? UserAction else { return }
        
        GDLogAppInfo("Continuing user action: \(userAction.rawValue)")
        
        if let action = CalloutButtonPanelAction(userAction: userAction) {
            performCalloutButtonAction(action, sender: notification.object as AnyObject?)
        }
    }
    
}

// MARK: Update View Methods

extension HomeViewController {
    
    fileprivate func updateExternalHardwareGeolocationIndicatorView(isExternal: Bool) {
        var buttons = sleepBarButton.map { [$0] } ?? []
        if isExternal {
            buttons.append(externalGPSBarButtonItem)
        }
        navigationItem.rightBarButtonItems = buttons
    }
    
}

// MARK: - DismissableViewControllerDelegate

extension HomeViewController: DismissableViewControllerDelegate {
    
    func onDismissed(_ viewController: UIViewController) {
        // If there is an active route guidance behavior, then unmute the audio beacon
        if AppContext.shared.eventProcessor.activeBehavior is RouteGuidance,
           !AppContext.shared.spatialDataContext.destinationManager.isAudioEnabled {
            AppContext.shared.spatialDataContext.destinationManager.toggleDestinationAudio()
        }
    }
    
}

// MARK: - SearchResultsViewControllerDelegate

extension HomeViewController: SearchResultsViewControllerDelegate {
    
    func didSelectSearchResult(_ searchResult: POI) {
        let detail = LocationDetail(entity: searchResult, telemetryContext: "search_result")
        showLocationDetail(detail)
        
        searchController?.isActive = false
    }
    
    var isCachingRequired: Bool {
        // After a result is selected, we will navigate to the detail view for that location
        // The detail view will disable any actions that require caching
        return false
    }
    
    var isAccessibilityActionsEnabled: Bool {
        return true
    }
    
    var telemetryContext: String {
        return "home_screen"
    }
}

// MARK: - LocationActionDelegate

extension HomeViewController: LocationActionDelegate {
    
    func didSelectLocationAction(_ action: LocationAction, detail: LocationDetail) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            guard action.isEnabled else {
                // Do nothing if the action is disabled
                return
            }
            
            self.searchController?.isActive = false
            
            do {
                switch action {
                case .save, .edit:
                    // Edit the marker at the given location
                    // Segue to the edit marker view
                    let config = EditMarkerConfig(detail: detail,
                                                  route: nil,
                                                  context: self.telemetryContext,
                                                  addOrUpdateAction: .popToRootViewController,
                                                  deleteAction: .popToRootViewController,
                                                  leftBarButtonItemIsHidden: false)
                    
                    AppNavigationModel.shared.openEditor(MarkerEditViewRepresentable(config: config))
                case .beacon:
                    // Set a beacon on the given location
                    // and segue to the home view
                    try LocationActionHandler.beacon(locationDetail: detail)
                    self.navigationController?.popToRootViewController(animated: true)
                case .preview:
                    self.showPreview(detail)
                case .share:
                    // Create a URL to share a marker at the given location
                    let url = try LocationActionHandler.share(locationDetail: detail)
                    // Present the activity view controller
                    let alert = ShareMarkerAlert.shareMarker(url, markerName: detail.displayName)
                    
                    if FirstUseExperience.didComplete(.share) {
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        let firstUseAlert = ShareMarkerAlert.firstUseExperience(dismissHandler: { [weak self] _ in
                            guard let `self` = self else {
                                return
                            }
                            
                            FirstUseExperience.setDidComplete(for: .share)
                            
                            self.present(alert, animated: true, completion: nil)
                        })
                        
                        self.present(firstUseAlert, animated: true, completion: nil)
                    }
                case .navilens:
                    launchNaviLens(detail: detail)
                    self.navigationController?.popToRootViewController(animated: true)
                }
            } catch let error as LocationActionError {
                let alert = LocationActionAlert.alert(for: error)
                self.present(alert, animated: true, completion: nil)
            } catch {
                let alert = LocationActionAlert.alert(for: error)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
}

// MARK: - UISearchControllerDelegate

extension HomeViewController: UISearchControllerDelegate {
    
    func willPresentSearchController(_ searchController: UISearchController) {
        // Default navigation bar
        navigationController?.navigationBar.configureAppearance(for: .default)
        
        NSUserActivity(userAction: .search).becomeCurrent()
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        // Transparent navigation bar
        navigationController?.navigationBar.configureAppearance(for: .transparentLightTitle)
    }
    
}

// MARK: - LargeBannerContainerView

extension HomeViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        layout.largeBannerHeight = height
    }
    
}

// MARK: - SmallBannerContainerView

extension HomeViewController: SmallBannerContainerView {
    
    func setSmallBannerHeight(_ height: CGFloat) {
        layout.smallBannerHeight = height
    }
    
}

private extension UIAlertController {
    
    static func activityDidUpdate() -> UIAlertController {
        let alert = UIAlertController(title: GDLocalizedString("route.update.success.title"), message: GDLocalizedString("route.update.success.message"), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .default))
        return alert
    }
    
    static func activityDidFailToUpdate() -> UIAlertController {
        let alert = UIAlertController(title: GDLocalizedString("route.update.fail.title"), message: GDLocalizedString("route.update.fail.message"), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .default))
        return alert
    }
    
    static func activityUpdateUnavailable() -> UIAlertController {
        let alert = UIAlertController(title: GDLocalizedString("route.update.unavailable.title"), message: GDLocalizedString("route.update.unavailable.message"), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .default))
        return alert
    }
    
}

private final class HomeHostingController: UIHostingController<HomeView> {
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        (parent as? HomeViewController)?.updatePanelSize(container)
    }
}
