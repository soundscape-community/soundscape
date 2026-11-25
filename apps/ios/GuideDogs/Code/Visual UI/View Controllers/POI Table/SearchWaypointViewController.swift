//
//  SearchWaypointViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

class SearchWaypointViewController: UIViewController {
    
    // MARK: Properties
    

    var routeName: String?
    var waypoints: Binding<[IdentifiableLocationDetail]>?
    private var hostingController: UIHostingController<WaypointSearchContent>?
    private var searchController: UISearchController?
    
    private var cancellable: AnyCancellable?
    
    // MARK: View Life Cycle
    
    deinit {
        cancellable?.cancel()
        cancellable = nil
    }
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(named: "Background Base")

        let host = UIHostingController(rootView: waypointContent)
        hostingController = host
        add(host) { content in
            [
                content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = GDLocalizedString("route_detail.edit.waypoints_button")
        
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
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        
        updateWaypointAddList()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: GDLocalizedString("general.alert.done"), style: .done, target: self, action: #selector(self.onDone))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        cancellable?.cancel()
        cancellable = nil
    }
    
    @objc private func onDone() {
        dismiss(animated: true)
    }

    private var waypointContent: WaypointSearchContent {
        WaypointSearchContent(
            waypoints: waypoints,
            showNearby: { [weak self] in
                guard let self else { return }
                let nearby = NearbyFilterViewController()
                nearby.delegate = self
                self.navigationController?.pushViewController(nearby, animated: true)
            },
            selectCurrentLocation: { [weak self] in
                guard let self else { return }
                guard let location = AppContext.shared.geolocationManager.location else {
                    self.present(ErrorAlerts.buildLocationAlert(), animated: true)
                    return
                }
                self.searchController?.isActive = false
                self.didSelect(currentLocation: location)
            }
        )
    }

    private func updateWaypointAddList() {
        hostingController?.rootView = waypointContent
    }

    private func addedMarker(id: String) {
        guard var waypoints = waypoints else {
            return
        }
        
        guard let detail = LocationDetail(markerId: id) else {
            return
        }
        
        guard waypoints.wrappedValue.contains(where: { $0.locationDetail.source == detail.source }) == false else {
            // Waypoint already exists
            return
        }
        
        // Add marker to waypoints
        let identifiable = IdentifiableLocationDetail(locationDetail: detail)
        waypoints.wrappedValue.append(identifiable)
        waypoints.update()
        
        updateWaypointAddList()
        
        // Reset search text
        searchController?.searchBar.searchTextField.text = nil
    }
    

}

// MARK: - POITableViewDelegate

extension SearchWaypointViewController: POITableViewDelegate {
    
    var poiAccessibilityHint: String {
        return GDLocalizedString("location_detail.add_waypoint.marker.hint")
    }
    
    var allowCurrentLocation: Bool {
        return true
    }
    
    var allowMarkers: Bool {
        return false
    }
    
    var usageLog: String {
        return "search_waypoint"
    }
    
    var doneNavigationItem: Bool {
        return true
    }
    
    private func didSelect(detail: LocationDetail) {
        if let markerId = detail.markerId {
            self.addedMarker(id: markerId)
            
            guard let navigationController = navigationController else {
                return
            }
            
            guard navigationController.topViewController != navigationController.viewControllers.first else {
                return
            }
            
            navigationController.popToRootViewController(animated: true)
        } else {
            let config = EditMarkerConfig(detail: detail,
                                          route: routeName,
                                          context: self.telemetryContext,
                                          addOrUpdateAction: .popToViewController(type: SearchWaypointViewController.self),
                                          deleteAction: nil,
                                          leftBarButtonItemIsHidden: false)
            
            if let vc = MarkerEditViewRepresentable(config: config).makeViewController() {
                self.navigationController?.pushViewController(vc, animated: true)
            }
            
            // Listen for a marker to be added
            cancellable = NotificationCenter.default.publisher(for: .markerAdded)
                .first()
                .compactMap({ $0.userInfo?[ReferenceEntity.Keys.entityId] as? String })
                .sink(receiveValue: { [weak self] markerId in
                    self?.addedMarker(id: markerId)
                })
        }
    }
    
    func didSelect(poi: POI) {
        didSelect(detail: LocationDetail(entity: poi))
    }
    
    func didSelect(currentLocation location: CLLocation) {
        didSelect(detail: LocationDetail(location: location))
    }
    
}

// MARK: - SearchResultsViewControllerDelegate

extension SearchWaypointViewController: SearchResultsViewControllerDelegate {
    
    func didSelectSearchResult(_ searchResult: POI) {
        didSelect(detail: LocationDetail(entity: searchResult))
    }
    
    var isCachingRequired: Bool {
        // Selected search results will be saved as a marker
        // Ensure that results can be cached (e.g., unencumbered coordinate is available)
        return true
    }
    
    var isAccessibilityActionsEnabled: Bool {
        // When a search result is selected, it will be saved as a marker
        // Disable custom accessibility actions (e.g., beacon, street preview, etc.)
        return false
    }
    
}

// MARK: - LocationActionDelegate

extension SearchWaypointViewController: LocationActionDelegate {
    
    var telemetryContext: String {
        return usageLog
    }
    
    func didSelectLocationAction(_ action: LocationAction, detail: LocationDetail) {
        // no-op
        //
        // `SearchWaypointController` implements `POITableViewDelegate` instead of `LocationActionDelegate`
        // Code should be cleaned up in the future so that view controllers (or SwiftUI views) do not
        // need to implement both protocols to support the search and browse experience.
    }
    
}


private struct WaypointSearchContent: View {
    let waypoints: Binding<[IdentifiableLocationDetail]>?
    let showNearby: () -> Void
    let selectCurrentLocation: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LocationBrowseButton(destination: .nearby, action: showNearby)
            if !AppContext.shared.isStreetPreviewing {
                Divider()
                LocationBrowseButton(destination: .currentLocation, action: selectCurrentLocation)
            }
            if let waypoints {
                WaypointAddList(waypoints: waypoints)
            }
        }
    }
}
