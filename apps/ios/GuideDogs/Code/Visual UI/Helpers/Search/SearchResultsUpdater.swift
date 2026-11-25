//
//  SearchResultsUpdater.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import MapKit

protocol SearchResultsUpdaterDelegate: AnyObject {
    func searchResultsDidStartUpdating()
    func searchResultsDidUpdate(_ searchResults: [POI], searchLocation: CLLocation?)
    func searchResultsDidUpdate(_ searchForMore: String?)
    func searchWasCancelled()
    var isPresentingDefaultResults: Bool { get }
    var telemetryContext: String { get }
    // Set `isCachingRequired = true` if a selected search result will
    // be cached on device
    // Search results can only be cached when an unencumbered coordinate is available
    var isCachingRequired: Bool { get }
}

class SearchResultsUpdater: NSObject {
    
    enum Context {
        case partialSearchText
        case completeSearchText
    }
    
    // MARK: Properties
    
    weak var delegate: SearchResultsUpdaterDelegate?
    private var location: CLLocation?
    var context: Context = .partialSearchText
    private var localSearch: MKLocalSearch?
    
    // MARK: Initialization
    
    override init() {
        super.init()
        
        // Save user's current location
        location = AppContext.shared.geolocationManager.location
        
        // Observe changes in user's location
        // This is required so that we can present all search
        // results with an accurate distance
        NotificationCenter.default.addObserver(self, selector: #selector(self.onLocationUpdated(_:)), name: Notification.Name.locationUpdated, object: nil)
    }
    
    deinit {
        localSearch?.cancel()
    }
    
    // MARK: Notifications
    
    @objc
    private func onLocationUpdated(_ notification: Notification) {
        guard let location = notification.userInfo?[SpatialDataContext.Keys.location] as? CLLocation else {
            return
        }
        
        self.location = location
    }
    
    // MARK: Selecting Search Results
    
    func selectSearchResult(_ poi: POI, completion: @escaping (SearchResult?, SearchResultError?) -> Void) {
        completion(.entity(poi), nil)
    }
    
}

extension SearchResultsUpdater {
    func update(query: String, context: Context) {
        cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            delegate?.searchResultsDidUpdate([], searchLocation: nil)
            return
        }

        delegate?.searchResultsDidStartUpdating()
        guard AppContext.shared.offlineContext.state == .online else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let location {
            let distance: CLLocationDistance = context == .partialSearchText ? 1000 : 5000
            request.region = MKCoordinateRegion(center: location.coordinate,
                                                latitudinalMeters: distance, longitudinalMeters: distance)
        }

        let search = MKLocalSearch(request: request)
        localSearch = search
        search.start { [weak self, weak search] response, _ in
            guard let self, let search, self.localSearch === search else { return }
            self.localSearch = nil
            let places = (response?.mapItems ?? []).compactMap(self.makePOI)
            let sorted = self.location.map { places.sorted(byDistanceFrom: $0) } ?? places
            if sorted.isEmpty {
                self.delegate?.searchResultsDidUpdate(context == .partialSearchText ? query : nil)
            } else {
                self.delegate?.searchResultsDidUpdate(sorted, searchLocation: self.location)
            }
        }
    }

    func cancel() {
        let search = localSearch
        localSearch = nil
        search?.cancel()
    }

    private func makePOI(_ item: MKMapItem) -> POI? {
        guard let coordinate = item.placemark.location?.coordinate, let name = item.name else { return nil }
        let place = item.placemark
        let address = [
            place.subThoroughfare,
            place.thoroughfare.map { $0 + "," },
            place.locality,
            place.administrativeArea,
            place.postalCode,
            place.country
        ].compactMap { $0 }.joined(separator: " ")
        return GenericLocation(lat: coordinate.latitude, lon: coordinate.longitude, name: name, address: address)
    }
}

extension SearchResultsUpdater: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        update(query: searchController.searchBar.text ?? "", context: context)
    }
}

extension SearchResultsUpdater: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }
        update(query: query, context: .completeSearchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancel()
        delegate?.searchWasCancelled()
    }
}
