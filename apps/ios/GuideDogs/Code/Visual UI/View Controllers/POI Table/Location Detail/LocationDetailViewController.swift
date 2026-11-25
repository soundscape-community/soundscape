//
//  LocationDetailViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine

class LocationDetailViewController: UIHostingController<LocationDetailScreen> {
    
    private let model = LocationDetailScreenModel()
    var largeBannerContainerView: UIView! { model.banner }

    init() {
        super.init(rootView: LocationDetailScreen(model: model))
        model.performAction = { [weak self] action, detail in
            self?.didSelectLocationAction(action, detail: detail)
        }
    }

    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    private var detailMapViewController: ExpandableMapViewController?
    
    var deleteAction: NavigationAction? = .popToRootViewController
    var onDismissPreviewHandler: (() -> Void)?
    var initialAction: (() -> LocationAction?)?
    var returnToHome: ((Bool) -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let action = initialAction?(), let detail = locationDetail else { return }
        LocationDetail.fetchNameAndAddressIfNeeded(for: detail) { [weak self] detail in
            self?.didSelectLocationAction(action, detail: detail)
        }
    }

    private func finishAtHome(focusOnBeacon: Bool = false) {
        if let returnToHome {
            returnToHome(focusOnBeacon)
        } else {
            navigationController?.popToRootViewController(animated: true)
        }
    }
    
    private var cancellable: AnyCancellable?
    
    var locationDetail: LocationDetail? {
        didSet {
            guard isViewLoaded else {
                return
            }
            
            reloadView()
        }
    }
    
    var waypointDetail: WaypointDetail? {
        didSet {
            locationDetail = waypointDetail?.locationDetail
        }
    }
    
    var isInPreviewController: Bool {
        guard let vc = self.navigationController?.viewControllers.first else { return false }
        return vc is PreviewViewController
    }
    
    // MARK: View Life Cycle
    
    deinit {
        cancellable?.cancel()
        cancellable = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let map = ExpandableMapViewController()
        if let detail = waypointDetail {
            map.style = .waypoint(detail: detail)
        } else if let detail = locationDetail {
            map.style = .location(detail: detail)
            map.isEditable = true
        }
        map.delegate = self
        addChild(map)
        map.view.frame = model.map.bounds
        map.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        model.map.addSubview(map.view)
        map.didMove(toParent: self)
        detailMapViewController = map
        model.detail = locationDetail
        view.accessibilityIgnoresInvertColors = true

        // Configure the back button
        self.navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        self.navigationController?.navigationBar.configureAppearance(for: .default)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        model.userLocation = AppContext.shared.geolocationManager.location

        guard let locationDetail = locationDetail else {
            return
        }
        
        if let markerId = locationDetail.markerId {
            cancellable = NotificationCenter.default.publisher(for: .markerUpdated).sink { notification in
                guard let id = notification.userInfo?[ReferenceEntity.Keys.entityId] as? String, id == markerId else {
                    return
                }
                
                guard let detail = LocationDetail(markerId: id) else {
                    return
                }
                
                self.locationDetail = detail
            }
        }
        
        // Show activity indicator
        model.isLoading = true
        
        if locationDetail.isMarker {
            // Reload the table view in case the marker details have
            // been updated since the view last appeared
            reloadView()
            
            // Hide activity indicator
            model.isLoading = false
        } else {
            // If the location is not a marker, try to fetch an estimated name and
            // address, if necessary
            LocationDetail.fetchNameAndAddressIfNeeded(for: locationDetail) { [weak self] (newValue) in
                guard let `self` = self else {
                    return
                }
                
                self.locationDetail = newValue
                
                // Hide activity indicator
                self.model.isLoading = false
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    private func reloadView() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            // Update view title
            if self.waypointDetail != nil {
                self.title = GDLocalizedString("location_detail.title.waypoint")
            } else if let detail = self.locationDetail, detail.isMarker {
                self.title = GDLocalizedString("location_detail.title.marker")
            } else {
                self.title = GDLocalizedString("location_detail.title.default")
            }
            
            self.model.detail = self.locationDetail
            
            if let detail = self.waypointDetail {
                self.detailMapViewController?.style = .waypoint(detail: detail)
            } else if let detail = self.locationDetail {
                self.detailMapViewController?.style = .location(detail: detail)
            }
        }
    }
    
}

// MARK: - EditableMapViewControllerDelegate

extension LocationDetailViewController: EditableMapViewControllerDelegate {
    
    var defaultToEditMode: Bool {
        return false
    }
    
    func viewController(_ viewController: UIViewController, didUpdateLocation locationDetail: LocationDetail, isAccessibilityEditing: Bool) {
        if locationDetail.isMarker {
            self.locationDetail = locationDetail
        } else {
            // Show activity indicator
            model.isLoading = true
            
            // If the location is not a marker, try to fetch an estimated name and
            // address, if necessary
            LocationDetail.fetchNameAndAddressIfNeeded(for: locationDetail) { [weak self] (newValue) in
                guard let `self` = self else {
                    return
                }
                
                self.locationDetail = newValue
                
                // Hide activity indicator
                self.model.isLoading = false
            }
        }
    }
    
}

// MARK: - LocationActionDelegate

extension LocationDetailViewController: LocationActionDelegate {
    
    func didSelectLocationAction(_ action: LocationAction, detail: LocationDetail) {
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            guard action.isEnabled else {
                // Do nothing if the action is disabled
                return
            }
            
            do {
                switch action {
                case .save:
                    // Save the marker at the given location
                    let config = EditMarkerConfig(detail: detail,
                                                  route: nil,
                                                  context: detail.telemetryContext ?? "",
                                                  addOrUpdateAction: .popViewController,
                                                  deleteAction: nil,
                                                  leftBarButtonItemIsHidden: false) { [weak self] newValue in
                        self?.locationDetail = newValue
                    }
                    
                    if let vc = MarkerEditViewRepresentable(config: config).makeViewController() {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                    
                case .edit:
                    // Edit the marker at the given location
                    let config = EditMarkerConfig(detail: detail,
                                                  route: nil,
                                                  context: detail.telemetryContext ?? "",
                                                  addOrUpdateAction: .popViewController,
                                                  deleteAction: self.deleteAction,
                                                  leftBarButtonItemIsHidden: false) { [weak self] newValue in
                        self?.locationDetail = newValue
                    }
                    
                    if let vc = MarkerEditViewRepresentable(config: config).makeViewController() {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                    
                case .beacon:
                    // Set a beacon on the given location
                    // and segue to the home view
                    try LocationActionHandler.beacon(locationDetail: detail)
                    
                    if let first = self.navigationController?.viewControllers.first, first === LaunchHelper.homePresenter {
                        AppNavigationModel.shared.shouldFocusOnBeacon = true
                    }
                    
                    if self.isPresentedModally && !self.isInPreviewController {
                        self.dismiss(animated: true)
                    } else {
                        self.finishAtHome(focusOnBeacon: true)
                    }
                    
                case .preview:
                    if AppContext.shared.isStreetPreviewing {
                        let alert = LocationActionAlert.restartPreview { [weak self] (_) in
                            if let self {
                                PreviewViewController.restart(from: self, at: detail)
                            }
                        }
                        
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        let preview = PreviewViewController.navigation(for: detail) { [weak self] in
                            self?.finishAtHome()
                        }
                        self.present(preview, animated: true)
                    }
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
                    
                    if self.isPresentedModally && !self.isInPreviewController {
                        self.dismiss(animated: true)
                    } else {
                        self.finishAtHome()
                    }
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

// MARK: - LargeBannerContainerView

extension LocationDetailViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        model.bannerHeight = height
    }
    
}
