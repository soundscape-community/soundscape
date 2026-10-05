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

enum SearchResultsState {
    case idle
    case loading
    case places([POI], location: CLLocation?)
    case noResults(searchForMore: String?)
    case offline
    case locationUnavailable
    case failure
}

protocol SearchResultsUpdaterDelegate: AnyObject {
    func searchResultsDidUpdate(_ state: SearchResultsState)
    func searchWasCancelled()
    var isPresentingDefaultResults: Bool { get }
    var telemetryContext: String { get }
    var isCachingRequired: Bool { get }
}

protocol SearchCancellation: AnyObject {
    func cancel()
}

extension MKLocalSearch: SearchCancellation {}
extension DispatchWorkItem: SearchCancellation {}

struct SearchSuggestion {
    let title: String
    let subtitle: String
    let request: MKLocalSearch.Request
}

protocol PlaceSearchService {
    func suggestions(for text: String, region: MKCoordinateRegion,
                     completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) -> SearchCancellation
    func search(_ request: MKLocalSearch.Request,
                completion: @escaping (Result<[MKMapItem], Error>) -> Void) -> SearchCancellation
}

protocol SearchScheduler {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> SearchCancellation
}

struct MainQueueSearchScheduler: SearchScheduler {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> SearchCancellation {
        let work = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return work
    }
}

struct MapKitPlaceSearchService: PlaceSearchService {
    func suggestions(for text: String, region: MKCoordinateRegion,
                     completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) -> SearchCancellation {
        return CompletionSearch(text: text, region: region, completion: completion)
    }

    func search(_ request: MKLocalSearch.Request,
                completion: @escaping (Result<[MKMapItem], Error>) -> Void) -> SearchCancellation {
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(response?.mapItems ?? []))
            }
        }
        return search
    }

    private final class CompletionSearch: NSObject, SearchCancellation, MKLocalSearchCompleterDelegate {
        private let completer = MKLocalSearchCompleter()
        private let completion: (Result<[SearchSuggestion], Error>) -> Void

        init(text: String, region: MKCoordinateRegion,
             completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) {
            self.completion = completion
            super.init()
            completer.delegate = self
            completer.region = region
            completer.resultTypes = [.address, .pointOfInterest, .query]
            if #available(iOS 18.0, *) {
                completer.regionPriority = .required
            }
            completer.queryFragment = text
        }

        func cancel() {
            completer.delegate = nil
            completer.cancel()
        }

        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            let suggestions = completer.results.map {
                SearchSuggestion(title: $0.title, subtitle: $0.subtitle,
                                 request: MKLocalSearch.Request(completion: $0))
            }
            cancel()
            completion(.success(suggestions))
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            cancel()
            completion(.failure(error))
        }
    }
}

class SearchResultsUpdater: NSObject {
    enum Context {
        case partialSearchText
        case completeSearchText
    }

    static let nearbyRadius: CLLocationDistance = 25_000
    weak var delegate: SearchResultsUpdaterDelegate?
    private(set) var searchBarButtonClicked = false
    var context: Context = .partialSearchText

    private let service: PlaceSearchService
    private let scheduler: SearchScheduler
    private let isOnline: () -> Bool
    private var location: CLLocation?
    private var generation = UUID()
    private var debounce: SearchCancellation?
    private var completer: SearchCancellation?
    private var searches: [UUID: SearchCancellation] = [:]
    private var query = ""
    private var isSubmitted = false
    private var pendingSuggestions: [SearchSuggestion] = []
    private var places: [POI] = []
    private var hadSuccessfulLookup = false
    private var waitingForLocation = false

    override convenience init() {
        self.init(service: MapKitPlaceSearchService(), scheduler: MainQueueSearchScheduler(),
                  location: AppContext.shared.geolocationManager.location,
                  isOnline: { AppContext.shared.offlineContext.state == .online })
        NotificationCenter.default.addObserver(self, selector: #selector(onLocationUpdated(_:)),
                                              name: Notification.Name.locationUpdated, object: nil)
    }

    init(service: PlaceSearchService, scheduler: SearchScheduler, location: CLLocation?,
         isOnline: @escaping () -> Bool) {
        self.service = service
        self.scheduler = scheduler
        self.location = location
        self.isOnline = isOnline
        super.init()
    }

    deinit {
        debounce?.cancel()
        completer?.cancel()
        searches.values.forEach { $0.cancel() }
    }

    @objc private func onLocationUpdated(_ notification: Notification) {
        guard let location = notification.userInfo?[SpatialDataContext.Keys.location] as? CLLocation else { return }
        Self.onMain { [weak self] in self?.updateLocation(location) }
    }

    func updateLocation(_ location: CLLocation) {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else { return }
        self.location = location
        if waitingForLocation {
            updateQuery(query, submitted: false)
        }
    }

    /// Invalidate before cancelling: cancellation can itself deliver a callback.
    func cancel() {
        generation = UUID()
        let oldDebounce = debounce
        let oldCompleter = completer
        let oldSearches = Array(searches.values)
        debounce = nil
        completer = nil
        searches.removeAll()
        pendingSuggestions.removeAll()
        places.removeAll()
        waitingForLocation = false
        query = ""
        oldDebounce?.cancel()
        oldCompleter?.cancel()
        oldSearches.forEach { $0.cancel() }
    }

    func updateQuery(_ text: String, submitted: Bool = false) {
        cancel()
        query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitted = submitted
        searchBarButtonClicked = submitted
        hadSuccessfulLookup = false
        guard !query.isEmpty else {
            delegate?.searchResultsDidUpdate(.idle)
            return
        }
        guard isOnline() else {
            delegate?.searchResultsDidUpdate(.offline)
            return
        }
        let center = location.flatMap { CLLocationCoordinate2DIsValid($0.coordinate) ? $0 : nil }
        if !submitted && center == nil {
            waitingForLocation = true
            delegate?.searchResultsDidUpdate(.locationUnavailable)
            return
        }
        delegate?.searchResultsDidUpdate(.loading)
        let currentGeneration = generation
        if submitted {
            GDATelemetry.track("search.request_made", with: ["context": delegate?.telemetryContext ?? ""])
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            if let center = center {
                request.region = Self.region(around: center)
            }
            startSearch(request, generation: currentGeneration, center: center, nearbyOnly: false)
        } else if let center = center {
            let text = query
            debounce = scheduler.schedule(after: 0.4) { [weak self] in
                guard let self = self, self.generation == currentGeneration else { return }
                self.debounce = nil
                guard self.isOnline() else {
                    self.delegate?.searchResultsDidUpdate(.offline)
                    return
                }
                GDATelemetry.track("autosuggest.request_made", with: ["context": self.delegate?.telemetryContext ?? ""])
                self.completer = self.service.suggestions(for: text, region: Self.region(around: center)) { [weak self] result in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.generation == currentGeneration else { return }
                        self.completer = nil
                        guard self.isOnline() else {
                            self.cancel()
                            self.delegate?.searchResultsDidUpdate(.offline)
                            return
                        }
                        switch result {
                        case .failure(let error):
                            self.delegate?.searchResultsDidUpdate(Self.isNoMatches(error) ? .noResults(searchForMore: text) : .failure)
                        case .success(let suggestions):
                            var seen = Set<String>()
                            self.pendingSuggestions = Array(suggestions.filter {
                                seen.insert($0.title + "\u{0}" + $0.subtitle).inserted
                            }.prefix(5))
                            if self.pendingSuggestions.isEmpty {
                                self.delegate?.searchResultsDidUpdate(.noResults(searchForMore: text))
                            } else {
                                self.resolveNext(generation: currentGeneration, center: center)
                            }
                        }
                    }
                }
            }
        }
    }

    private static func region(around location: CLLocation) -> MKCoordinateRegion {
        return MKCoordinateRegion(center: location.coordinate, latitudinalMeters: nearbyRadius * 2,
                                  longitudinalMeters: nearbyRadius * 2)
    }

    private func resolveNext(generation: UUID, center: CLLocation) {
        while self.generation == generation && searches.count < 2 && !pendingSuggestions.isEmpty {
            let request = pendingSuggestions.removeFirst().request
            request.region = Self.region(around: center)
            if #available(iOS 18.0, *) {
                request.regionPriority = .required
            }
            startSearch(request, generation: generation, center: center, nearbyOnly: true)
        }
    }

    private func startSearch(_ request: MKLocalSearch.Request, generation: UUID,
                             center: CLLocation?, nearbyOnly: Bool) {
        let identifier = UUID()
        let search = service.search(request) { [weak self] result in
            // Always enqueue so even a synchronous service cannot complete before its handle is retained.
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.generation == generation else { return }
                self.searches.removeValue(forKey: identifier)
                guard self.isOnline() else {
                    self.cancel()
                    self.delegate?.searchResultsDidUpdate(.offline)
                    return
                }
                switch result {
                case .success(let items):
                    self.hadSuccessfulLookup = true
                    self.addPlaces(items, center: center, nearbyOnly: nearbyOnly)
                case .failure(let error):
                    if Self.isNoMatches(error) { self.hadSuccessfulLookup = true }
                }
                if nearbyOnly, let center = center {
                    self.resolveNext(generation: generation, center: center)
                }
                if !self.places.isEmpty {
                    let sorted = center.map { self.places.sorted(byDistanceFrom: $0) } ?? self.places
                    self.delegate?.searchResultsDidUpdate(.places(sorted, location: center))
                } else if self.searches.isEmpty && self.pendingSuggestions.isEmpty {
                    let state: SearchResultsState = self.hadSuccessfulLookup
                        ? .noResults(searchForMore: self.isSubmitted ? nil : self.query) : .failure
                    self.delegate?.searchResultsDidUpdate(state)
                }
            }
        }
        searches[identifier] = search
    }

    private func addPlaces(_ items: [MKMapItem], center: CLLocation?, nearbyOnly: Bool) {
        for item in items {
            guard let location = item.placemark.location, CLLocationCoordinate2DIsValid(location.coordinate),
                  let name = item.name, !name.isEmpty else { continue }
            if nearbyOnly, let center = center, location.distance(from: center) > Self.nearbyRadius { continue }
            guard !places.contains(where: { $0.name == name && $0.centroidLatitude == location.coordinate.latitude
                && $0.centroidLongitude == location.coordinate.longitude }) else { continue }
            let placemark = item.placemark
            let address = [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality,
                           placemark.administrativeArea, placemark.postalCode, placemark.country]
                .compactMap { $0 }.joined(separator: " ")
            places.append(GenericLocation(lat: location.coordinate.latitude, lon: location.coordinate.longitude,
                                          name: name, address: address))
        }
    }

    private static func isNoMatches(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == MKError.errorDomain && error.code == MKError.placemarkNotFound.rawValue
    }

    private static func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    func selectSearchResult(_ poi: POI, completion: @escaping (SearchResult?, SearchResultError?) -> Void) {
        if let delegate = delegate, delegate.isPresentingDefaultResults {
            GDATelemetry.track("recent_entity_selected.search", with: ["context": delegate.telemetryContext])
        }
        completion(.entity(poi), nil)
    }
}

extension SearchResultsUpdater: UISearchResultsUpdating, UISearchBarDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        updateQuery(searchController.searchBar.text ?? "", submitted: context == .completeSearchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        updateQuery(searchBar.text ?? "", submitted: true)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancel()
        delegate?.searchWasCancelled()
        delegate?.searchResultsDidUpdate(.idle)
    }
}
