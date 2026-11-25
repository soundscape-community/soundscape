//
//  SearchTableViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI
import CoreLocation

class SearchTableViewController: UIViewController {
    private let model = LocationBrowseModel()
    var largeBannerContainerView: UIView! { model.banner }
    weak var delegate: POITableViewDelegate?
    private var searchController: UISearchController?
    var onDismissPreviewHandler: (() -> Void)?
    // If no delegate is provided, `logContext` allows for setting the context for the screen_view telemetry log
    var logContext: String = ""
    
    private var moreLocations: [HomeBrowseDestination] {
        var rows: [HomeBrowseDestination] = [.nearby]
        
        if delegate?.allowMarkers ?? true {
            rows.append(.markers)
        }
        
        if delegate?.allowCurrentLocation ?? true && AppContext.shared.isStreetPreviewing == false {
            rows.append(.currentLocation)
        }
        
        return rows
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = GDLocalizedString("poi_screen.screen_title.select_a_location")
        let host = UIHostingController(rootView: LocationBrowseScreen(model: model, destinations: moreLocations) { [weak self] destination in
            self?.didSelect(destination)
        })
        add(host) { content in
            [
                content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        }

        // Initialize search controller
        self.searchController = UISearchController(delegate: self)
        
        // Add search controller to navigation bar
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false

        // Don't allow iOS 26 to move the search to the bottom.
        if #available(iOS 26.0, *) {
            self.navigationItem.searchBarPlacementAllowsToolbarIntegration = false
        }
        
        // Search results will be displayed modally
        // Use this view controller to define presentation context
        self.definesPresentationContext = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        searchController?.isActive = false
    }
    
    private func showDetail(_ detail: LocationDetail) {
        let controller = LocationDetailViewController()
        controller.locationDetail = detail
        controller.onDismissPreviewHandler = onDismissPreviewHandler
        navigationController?.pushViewController(controller, animated: true)
    }

}

extension SearchTableViewController: SearchResultsViewControllerDelegate {
    
    func didSelectSearchResult(_ searchResult: POI) {
        if let delegate = delegate {
            delegate.didSelect(poi: searchResult)
        } else {
            let detail = LocationDetail(entity: searchResult, telemetryContext: "search_result")
            showDetail(detail)
        }
    }
    
    var telemetryContext: String {
        return delegate?.usageLog ?? ""
    }
    
    var isCachingRequired: Bool {
        if let delegate = delegate {
            return delegate.isCachingRequired
        } else {
            // After a result is selected, we will navigate to the detail view for that location
            // The detail view will disable any actions that require caching
            return true
        }
    }
    
    var isAccessibilityActionsEnabled: Bool {
        // If there is no delegate, we will navigate to the detail view for a selected location
        // In this scenario, enable custom accessibility actions
        return delegate == nil
    }
    
}

extension SearchTableViewController {
    
    private func didSelect(_ destination: HomeBrowseDestination) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            switch destination {
            case .nearby:
                let nearby = NearbyFilterViewController()
                nearby.delegate = self.delegate
                nearby.onDismissPreviewHandler = self.onDismissPreviewHandler
                self.navigationController?.pushViewController(nearby, animated: true)
            case .markers:
                let markers = MarkersAndRoutesListHostViewController()
                markers.onDismissPreviewHandler = self.onDismissPreviewHandler
                self.navigationController?.pushViewController(markers, animated: true)
            case .currentLocation:
                guard let location = AppContext.shared.geolocationManager.location else {
                    self.present(ErrorAlerts.buildLocationAlert(), animated: true, completion: nil)
                    return
                }
                
                // Dismiss `UISearchResultsController`
                self.searchController?.isActive = false
                
                if let delegate = self.delegate {
                    delegate.didSelect(currentLocation: location)
                } else {
                    let detail = LocationDetail(location: location, telemetryContext: "current_location")
                    self.showDetail(detail)
                }
            }
        }
    }
    
}

extension SearchTableViewController: LocationActionDelegate {
    
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

extension SearchTableViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        model.bannerHeight = height
    }
    
}


private final class LocationBrowseModel: ObservableObject {
    let banner = UIView()
    @Published var bannerHeight: CGFloat = 0
}

private struct LocationBrowseScreen: View {
    @ObservedObject var model: LocationBrowseModel
    let destinations: [HomeBrowseDestination]
    let select: (HomeBrowseDestination) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EmbeddedView(content: model.banner)
                .frame(height: model.bannerHeight)
                .clipped()
                .accessibilityHidden(model.bannerHeight == 0)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(destinations, id: \.self) { destination in
                        LocationBrowseButton(destination: destination) { select(destination) }
                    }
                }
            }
            .background(Color("Background Base"))
        }
    }
}
