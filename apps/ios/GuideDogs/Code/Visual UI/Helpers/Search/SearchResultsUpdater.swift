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
    case noResults
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
    func suggestions(for text: String, region: MKCoordinateRegion?, nearbyOnly: Bool,
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
    func suggestions(for text: String, region: MKCoordinateRegion?, nearbyOnly: Bool,
                     completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) -> SearchCancellation {
        return CompletionSearch(text: text, region: region, nearbyOnly: nearbyOnly, completion: completion)
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

        init(text: String, region: MKCoordinateRegion?, nearbyOnly: Bool,
             completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) {
            self.completion = completion
            super.init()
            completer.delegate = self
            if let region = region { completer.region = region }
            completer.resultTypes = [.address, .pointOfInterest, .query]
            if #available(iOS 18.0, *) {
                completer.regionPriority = nearbyOnly ? .required : .default
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
    enum Scope: Int {
        case nearby
        case anywhere

        var title: String {
            switch self {
            case .nearby: return GDLocalizedString("search.scope.nearby")
            case .anywhere: return GDLocalizedString("search.scope.anywhere")
            }
        }
    }

    static let nearbyRadius: CLLocationDistance = 25_000
    weak var delegate: SearchResultsUpdaterDelegate?
    private(set) var searchBarButtonClicked = false
    private(set) var scope: Scope = .nearby

    private let service: PlaceSearchService
    private let scheduler: SearchScheduler
    private let isOnline: () -> Bool
    private var location: CLLocation?
    private var generation = UUID()
    private var debounce: SearchCancellation?
    private var pendingStart: (() -> Void)?
    private var currentState: SearchResultsState = .idle
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
            updateQuery(query, submitted: isSubmitted)
        }
    }

    /// Invalidate before cancelling: cancellation can itself deliver a callback.
    func cancel() {
        generation = UUID()
        let oldDebounce = debounce
        let oldCompleter = completer
        let oldSearches = Array(searches.values)
        debounce = nil
        pendingStart = nil
        currentState = .idle
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

    func setScope(_ scope: Scope) {
        guard self.scope != scope else { return }
        let text = query
        let submitted = isSubmitted
        cancel()
        self.scope = scope
        updateQuery(text, submitted: submitted)
    }

    private func publish(_ state: SearchResultsState) {
        currentState = state
        delegate?.searchResultsDidUpdate(state)
    }

    func updateQuery(_ text: String, submitted: Bool = false) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Submitting a nearby search finishes the same autocomplete operation. It must
        // not reinterpret a fragment (for example, "th") as a global place name.
        if submitted && scope == .nearby && text == query && !text.isEmpty && isOnline() {
            switch currentState {
            case .loading, .places, .noResults:
                isSubmitted = true
                searchBarButtonClicked = true
                GDATelemetry.track("search.request_made", with: ["context": delegate?.telemetryContext ?? ""])
                let start = pendingStart
                debounce?.cancel()
                debounce = nil
                start?()
                // Redisplay the same results so VoiceOver can move to the list when
                // the Search button dismisses the keyboard.
                switch currentState {
                case .places, .noResults: publish(currentState)
                default: break
                }
                return
            default: break
            }
        }
        cancel()
        query = text
        isSubmitted = submitted
        searchBarButtonClicked = submitted
        hadSuccessfulLookup = false
        guard !query.isEmpty else {
            publish(.idle)
            return
        }
        guard isOnline() else {
            publish(.offline)
            return
        }
        let nearbyOnly = scope == .nearby
        let center = location.flatMap { CLLocationCoordinate2DIsValid($0.coordinate) ? $0 : nil }
        if nearbyOnly && center == nil {
            waitingForLocation = true
            publish(.locationUnavailable)
            return
        }
        publish(.loading)
        let currentGeneration = generation
        if submitted { GDATelemetry.track("search.request_made", with: ["context": delegate?.telemetryContext ?? ""]) }
        if submitted && !nearbyOnly {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            if let center = center { request.region = Self.region(around: center) }
            startSearch(request, generation: currentGeneration, center: center, nearbyOnly: false, resolvingSuggestion: false)
        } else {
            let text = query
            let start = { [weak self] in
                guard let self = self, self.generation == currentGeneration, self.pendingStart != nil else { return }
                self.debounce = nil
                self.pendingStart = nil
                guard self.isOnline() else {
                    self.publish(.offline)
                    return
                }
                GDATelemetry.track("autosuggest.request_made", with: ["context": self.delegate?.telemetryContext ?? ""])
                self.completer = self.service.suggestions(for: text, region: center.map(Self.region), nearbyOnly: nearbyOnly) { [weak self] result in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.generation == currentGeneration else { return }
                        self.completer = nil
                        guard self.isOnline() else {
                            self.cancel()
                            self.publish(.offline)
                            return
                        }
                        switch result {
                        case .failure(let error):
                            self.publish(Self.isNoMatches(error) ? .noResults : .failure)
                        case .success(let suggestions):
                            var seen = Set<String>()
                            self.pendingSuggestions = Array(suggestions.filter {
                                seen.insert($0.title + "\u{0}" + $0.subtitle).inserted
                            }.prefix(5))
                            if self.pendingSuggestions.isEmpty {
                                self.publish(.noResults)
                            } else {
                                self.resolveNext(generation: currentGeneration, center: center, nearbyOnly: nearbyOnly)
                            }
                        }
                    }
                }
            }
            pendingStart = start
            if submitted {
                start()
            } else {
                debounce = scheduler.schedule(after: 0.4, start)
            }
        }
    }

    private static func region(around location: CLLocation) -> MKCoordinateRegion {
        return MKCoordinateRegion(center: location.coordinate, latitudinalMeters: nearbyRadius * 2,
                                  longitudinalMeters: nearbyRadius * 2)
    }

    private func resolveNext(generation: UUID, center: CLLocation?, nearbyOnly: Bool) {
        while self.generation == generation && searches.count < 2 && !pendingSuggestions.isEmpty {
            let request = pendingSuggestions.removeFirst().request
            if let center = center { request.region = Self.region(around: center) }
            if #available(iOS 18.0, *) {
                request.regionPriority = nearbyOnly ? .required : .default
            }
            startSearch(request, generation: generation, center: center, nearbyOnly: nearbyOnly, resolvingSuggestion: true)
        }
    }

    private func startSearch(_ request: MKLocalSearch.Request, generation: UUID,
                             center: CLLocation?, nearbyOnly: Bool, resolvingSuggestion: Bool) {
        let identifier = UUID()
        let search = service.search(request) { [weak self] result in
            // Always enqueue so even a synchronous service cannot complete before its handle is retained.
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.generation == generation else { return }
                self.searches.removeValue(forKey: identifier)
                guard self.isOnline() else {
                    self.cancel()
                    self.publish(.offline)
                    return
                }
                switch result {
                case .success(let items):
                    self.hadSuccessfulLookup = true
                    self.addPlaces(items, center: center, nearbyOnly: nearbyOnly)
                case .failure(let error):
                    if Self.isNoMatches(error) { self.hadSuccessfulLookup = true }
                }
                if resolvingSuggestion {
                    self.resolveNext(generation: generation, center: center, nearbyOnly: nearbyOnly)
                }
                if !self.places.isEmpty {
                    let sorted = center.map { self.places.sorted(byDistanceFrom: $0) } ?? self.places
                    self.publish(.places(sorted, location: center))
                } else if self.searches.isEmpty && self.pendingSuggestions.isEmpty {
                    let state: SearchResultsState = self.hadSuccessfulLookup
                        ? .noResults : .failure
                    self.publish(state)
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
        let text = searchController.searchBar.text ?? ""
        if isSubmitted && text.trimmingCharacters(in: .whitespacesAndNewlines) == query { return }
        updateQuery(text)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        updateQuery(searchBar.text ?? "", submitted: true)
        searchBar.searchTextField.endEditing(true)
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        guard let scope = Scope(rawValue: selectedScope) else { return }
        setScope(scope)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancel()
        delegate?.searchWasCancelled()
        publish(.idle)
    }
}
