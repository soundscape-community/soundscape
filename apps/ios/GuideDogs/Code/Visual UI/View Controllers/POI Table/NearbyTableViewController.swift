//
//  NearbyResultsViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import CoreLocation
import SwiftUI

// Presents nearby SwiftUI results when a legacy flow still owns navigation.
class NearbyResultsViewController: UIViewController, POITableViewController {
    private lazy var activityIndicatorView = makePOILoadingOverlay()
    weak var delegate: POITableViewDelegate?
    var context: NearbyDataContext?
    var currentFilter = NearbyTableFilter.defaultFilter
    var onDismissPreviewHandler: (() -> Void)?

    var telemetryContext: String {
        if let usageLog = delegate?.usageLog, usageLog.isEmpty == false {
            return "\(usageLog).nearby_places"
        }
        
        return "nearby_places"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = title ?? GDLocalizedString("search.nearby.screen_title")
        navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        if delegate?.doneNavigationItem == true {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: GDLocalizedString("general.alert.done"),
                primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
            )
        }

        let results = NearbyResultsContent(
            context: context ?? NearbyDataContext(),
            initialFilter: currentFilter.type,
            allowsActions: delegate == nil,
            select: { [weak self] in self?.didSelect($0) },
            perform: { [weak self] in self?.didSelectLocationAction($0, entity: $1) }
        )
        let host = UIHostingController(rootView: results)
        add(host) { content in
            [
                content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        }
    }

    private func showDetail(_ detail: LocationDetail) {
        let controller = LocationDetailViewController()
        controller.locationDetail = detail
        controller.deleteAction = .popToViewController(type: NearbyResultsViewController.self)
        controller.onDismissPreviewHandler = onDismissPreviewHandler
        navigationController?.pushViewController(controller, animated: true)
    }

    private func didSelect(_ entity: POI) {
        if let delegate = delegate {
            delegate.didSelect(poi: entity)
        } else {
            let detail = LocationDetail(entity: entity, telemetryContext: telemetryContext)
            showDetail(detail)
        }
    }
    
    private func presentActivityIndicatorView() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            // Show activity indicator
            self.view.addSubview(self.activityIndicatorView)
            // Update size and constraints
            self.activityIndicatorView.frame = self.view.bounds
            self.activityIndicatorView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            self.activityIndicatorView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
            self.activityIndicatorView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
            self.activityIndicatorView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        }
    }
    
    private func dismissActivityIndicatorView() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            self.activityIndicatorView.removeFromSuperview()
        }
    }
    
}

extension NearbyResultsViewController: LocationAccessibilityActionDelegate {
    
    func didSelectLocationAction(_ action: LocationAction, entity: POI) {
        
        let detail = LocationDetail(entity: entity, telemetryContext: self.telemetryContext)
        
        self.presentActivityIndicatorView()
        
        LocationDetail.fetchNameAndAddressIfNeeded(for: detail) { [weak self] (detail) in
            guard let `self` = self else {
                return
            }
            
            self.dismissActivityIndicatorView()
            
            self.didSelectLocationAction(action, detail: detail)
        }
    }
    
    private func didSelectLocationAction(_ action: LocationAction, detail: LocationDetail) {
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
                case .save, .edit:
                    // Edit the marker at the given location
                    // Segue to the edit marker view
                    let config = EditMarkerConfig(detail: detail,
                                                  route: nil,
                                                  context: self.telemetryContext,
                                                  addOrUpdateAction: .popViewController,
                                                  deleteAction: .popViewController,
                                                  leftBarButtonItemIsHidden: false)
                    
                    if let vc = MarkerEditViewRepresentable(config: config).makeViewController() {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                    
                case .beacon:
                    // Set a beacon on the given location
                    // and segue to the home view
                    try LocationActionHandler.beacon(locationDetail: detail)
                    self.navigationController?.popToRootViewController(animated: true)
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
                            self?.navigationController?.popToRootViewController(animated: true)
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
