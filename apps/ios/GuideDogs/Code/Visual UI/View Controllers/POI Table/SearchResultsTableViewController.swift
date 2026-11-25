//
//  SearchResultsViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import UIKit
import SwiftUI

protocol SearchResultsViewControllerDelegate: LocationActionDelegate {
    func didSelectSearchResult(_ searchResult: POI)
    var telemetryContext: String { get }
    // Set `isCachingRequired = true` if a selected search result will
    // be cached on device
    // Search results can only be cached when an unencumbered coordinate is available
    var isCachingRequired: Bool { get }
    // Set `isAccessibilityActionsEnabled = false` when search results should not include
    // custom accessibility actions (e.g., set beacon, save as marker, etc.)
    //
    // One example of when this will be false is the marker and beacon tutorials
    var isAccessibilityActionsEnabled: Bool { get }
}

class SearchResultsViewController: UIViewController {
    enum ViewConfiguration {
        case embedded, standalone
    }

    var viewConfiguration = ViewConfiguration.embedded
    weak var delegate: SearchResultsViewControllerDelegate?
    let searchResultsUpdater = SearchResultsUpdater()

    private let results = SearchResultsModel()
    private var currentVoiceoverAnnouncement: String?
    private(set) var isPresentingDefaultResults = false
    private var wasSearchCancelled = false

    private var searchController: UISearchController? {
        if isPresentedModally {
            return self.navigationItem.searchController
        } else {
            return self.parent as? UISearchController
        }
    }
    
    // MARK: Standalone configuration
    
    static func instantiateStandaloneConfiguration() -> NavigationController? {
        let searchVC = SearchResultsViewController()
        searchVC.viewConfiguration = .standalone
        
        let searchController = UISearchController(searchResultsController: searchVC, delegate: searchVC, displayInPlace: true)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.automaticallyShowsCancelButton = false
        
        searchVC.navigationItem.searchController = searchController
        searchVC.navigationItem.hidesSearchBarWhenScrolling = false

        // Don't allow iOS 26 to move the search to the bottom.
        if #available(iOS 26.0, *) {
            searchVC.navigationItem.searchBarPlacementAllowsToolbarIntegration = false
        }
        
        let navigationVC = NavigationController(rootViewController: searchVC)
        return navigationVC
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "Background Base")
        extendedLayoutIncludesOpaqueBars = true
        let host = UIHostingController(rootView: SearchResultsScreen(
            model: results,
            select: { [weak self] in self?.didSelectEntityResult($0) },
            selectQuery: { [weak self] in self?.didSelectSearchStringResult($0) },
            perform: { [weak self] in self?.didSelectLocationAction($0, entity: $1) }
        ))
        add(host) { content in
            [
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
        }

        if viewConfiguration == .standalone {
            self.title = GDLocalizedString("preview.search.label")
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: GDLocalizedString("general.alert.cancel"),
                                                                    style: .plain,
                                                                    target: self,
                                                                    action: #selector(dismissViewController))
        } else {
            self.navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Reset wasSearchCancelled flag
        wasSearchCancelled = false
        
        results.allowsActions = delegate?.isAccessibilityActionsEnabled ?? false
        results.location = AppContext.shared.geolocationManager.location

        // Initialize recent selections
        let selections = SpatialDataCache.recentlySelectedObjects()
        
        // Initialize recent callouts
        let callouts: [POI] = AppContext.shared.calloutHistory.callouts
            .sorted(by: { return $0.timestamp > $1.timestamp })
            .compactMap({
                var poi: POI?
            
                if let callout = $0 as? POICallout {
                    poi = callout.poi
                } else if let callout = $0 as? IntersectionCallout, let intersection = callout.intersection {
                    let latitude = intersection.location.coordinate.latitude
                    let longitude = intersection.location.coordinate.longitude
                    let name = GDLocalizedString("intersection.named_intersection", intersection.localizedName)
                    
                    poi = GenericLocation(lat: latitude, lon: longitude, name: name)
                } else if let callout = $0 as? WaypointArrivalCallout, let id = callout.waypoint.markerId, let marker = SpatialDataCache.referenceEntityByKey(id) {
                    poi = marker.getPOI()
                }
                
                return poi
            })
        
        results.recent = selections
        results.callouts = callouts
        updateResults(.recent, isDefault: true)

        searchResultsUpdater.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        searchResultsUpdater.delegate = nil
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
    
    private func updateResults(_ content: SearchResultsModel.Content, isDefault: Bool = false, announcement: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.announce(_:)),
                                                   object: self.currentVoiceoverAnnouncement)
            self.currentVoiceoverAnnouncement = nil
            self.isPresentingDefaultResults = isDefault
            self.results.content = content
            self.results.showsEmptyMessage = !(self.searchController?.searchBar.searchTextField.isEditing ?? false)
            guard !self.wasSearchCancelled else { return }

            if self.results.showsEmptyMessage {
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
            if let announcement {
                self.currentVoiceoverAnnouncement = announcement
                self.perform(#selector(self.announce(_:)), with: announcement, afterDelay: 1)
            }
        }
    }

    @objc private func announce(_ announcement: String?) {
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    // MARK: Error Handling
    
    private func presentErrorAlert(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            // Failed to save selected entity
            let title = GDLocalizedString("universal_links.alert.error.title")
            let message = GDLocalizedString("location_detail.disabled.generic")
            let alert = ErrorAlerts.buildGeneric(title: title, message: message, dismissHandler: { [weak self] _ in
                self?.dismissActivityIndicator()
            })
            
            // Display error alert
            self?.present(alert, animated: true, completion: completion)
        }
    }
    
    private func presentActivityIndicator() {
        DispatchQueue.main.async { [weak self] in self?.results.isResolvingPlace = true }
    }

    private func dismissActivityIndicator() {
        DispatchQueue.main.async { [weak self] in self?.results.isResolvingPlace = false }
    }
}

// MARK: - SearchResultsUpdaterDelegate

extension SearchResultsViewController: SearchResultsUpdaterDelegate {
    
    func searchResultsDidStartUpdating() {
        if AppContext.shared.offlineContext.state == .online {
            updateResults(.searching)
        } else {
            updateResults(.offline, announcement: GDLocalizedString("searching.offline"))
        }
    }

    func searchResultsDidUpdate(_ places: [POI], searchLocation: CLLocation?) {
        if let first = places.first {
            let announcement = GDLocalizedString("search.results_found_first_result", String(places.count), first.localizedName)
            updateResults(.results(places, searchLocation), announcement: announcement)
        } else {
            updateResults(.recent, isDefault: true)
        }
    }

    func searchResultsDidUpdate(_ searchForMore: String?) {
        let announcement = GDLocalizedString(searchForMore == nil ? "search.no_results_found_with_hint" : "search.no_results_found_with_action")
        updateResults(.noResults(searchForMore), announcement: announcement)
    }

    func searchWasCancelled() {
        wasSearchCancelled = true
    }
    
    var telemetryContext: String {
        guard delegate !== self else {
            return ""
        }
        
        return delegate?.telemetryContext ?? ""
    }
    
    var isCachingRequired: Bool {
        // `delegate` should never be `nil`, but if it is, assume that caching
        // is required
        guard delegate !== self else {
            return true
        }
        
        return delegate?.isCachingRequired ?? true
    }
    
}

// MARK: - Result selection

extension SearchResultsViewController {
    private func didSelectEntityResult(_ poi: POI) {
        // Display activity indicator
        presentActivityIndicator()
        
        // Fetch entity data
        searchResultsUpdater.selectSearchResult(poi) { [weak self] (result, error) in
            guard let `self` = self else {
                return
            }
            
            self.dismissActivityIndicator()
            
            if error == nil {
                switch result {
                case .entity(let value): self.dismissOnDidSelectSearchResult(value)
                case .suggestion(let value): self.didSelectSearchStringResult(value)
                case .none: self.presentErrorAlert()
                }
            } else {
                self.presentErrorAlert()
            }
        }
    }
    
    private func didSelectSearchStringResult(_ searchString: String) {
        // Stop editing and remove current search results
        searchController?.searchBar.searchTextField.endEditing(false)
        
        // Indicate that the new search text is complete
        searchResultsUpdater.context = .completeSearchText
        
        // Update search bar text
        searchController?.searchBar.text = searchString
        
        // Reset context
        searchResultsUpdater.context = .partialSearchText
    }
    
    private func dismissOnDidSelectSearchResult(_ entity: POI) {
        // If the selected result will be cached on device but caching is not enabled
        // (e.g., unencumbered coordinate is not available), present the error alert
        // and return
        if isCachingRequired {
            let detail = LocationDetail(entity: entity)
            
            guard detail.source.isCachingEnabled else {
                self.presentErrorAlert()
                return
            }
        }
        
        let completion = { [weak self] in
            guard let `self` = self else {
                return
            }
            
            if self.isPresentingDefaultResults == false {
                // If the user has selected a result from a search, update
                // the last selected date for that result
                let detail = LocationDetail(entity: entity)
                detail.updateLastSelectedDate()
            }
            
            self.delegate?.didSelectSearchResult(entity)
        }
        
        if viewConfiguration == .embedded {
            self.dismiss(animated: true) {
                completion()
            }
        } else {
            completion()
        }
    }
    
}

// MARK: - LocationAccessibilityActionDelegate

extension SearchResultsViewController: LocationAccessibilityActionDelegate {
    
    func didSelectLocationAction(_ action: LocationAction, entity: POI) {
        // Display activity indicator
        presentActivityIndicator()
        
        // Fetch entity data
        searchResultsUpdater.selectSearchResult(entity) { [weak self] (result, error) in
            guard let `self` = self else {
                return
            }
            
            if let result = result, error == nil {
                switch result {
                case .entity(let value):
                    var context = "search_results"
                    
                    if let telemetryContext = self.delegate?.telemetryContext, telemetryContext.isEmpty == false {
                        context = "\(telemetryContext).search_results"
                    }
                    
                    let detail = LocationDetail(entity: value, telemetryContext: context)
                    
                    LocationDetail.fetchNameAndAddressIfNeeded(for: detail) { [weak self] (newValue) in
                        guard let `self` = self else {
                            return
                        }
                        
                        self.dismissActivityIndicator()
                        
                        self.dismiss(animated: true) { [weak self] in
                            guard let `self` = self else {
                                return
                            }
                            
                            self.delegate?.didSelectLocationAction(action, detail: newValue)
                        }
                    }
                default:
                    // Actions are only available for entity results
                    // and should not be available for search suggestions
                    self.presentErrorAlert()
                }
            } else {
                self.presentErrorAlert()
            }
        }
    }
    
}

// MARK: - SearchResultsViewControllerDelegate

/// The methods and properties in this delegate will only be used when the `viewConfiguration` is `standalone`
extension SearchResultsViewController: SearchResultsViewControllerDelegate {
    
    /// Invoked when selecting a search result via a custom VoiceOver action
    func didSelectLocationAction(_ action: LocationAction, detail: LocationDetail) {
        // no-op
    }
    
    /// Invoked when selecting a search result via tap
    func didSelectSearchResult(_ searchResult: POI) {
        let viewController = LocationDetailViewController()
        viewController.locationDetail = LocationDetail(entity: searchResult, telemetryContext: "search_result")
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
    var isAccessibilityActionsEnabled: Bool {
        return true
    }
    
}
