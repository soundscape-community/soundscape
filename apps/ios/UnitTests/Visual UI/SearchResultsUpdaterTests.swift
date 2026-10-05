//
//  SearchResultsUpdaterTests.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
import MapKit
@testable import Soundscape

final class SearchResultsUpdaterTests: XCTestCase {
    private let center = CLLocation(latitude: 51.5, longitude: -0.1)
    private var service: FakeSearchService!
    private var scheduler: FakeSearchScheduler!
    private var delegate: SearchDelegate!
    private var updater: SearchResultsUpdater!
    private var online = true

    override func setUp() {
        super.setUp()
        resetSearch(location: center)
    }

    override func tearDown() {
        updater.cancel()
        updater = nil
        delegate = nil
        scheduler = nil
        service = nil
        super.tearDown()
    }

    func testShortQueryIsTrimmedAndDebounced() {
        updater.updateQuery(" c ")
        XCTAssertTrue(service.suggestionCalls.isEmpty)
        scheduler.runLast()
        XCTAssertEqual(service.suggestionCalls[0].text, "c")
    }

    func testEditCancelsDebounceAndIgnoresItsLateAction() {
        updater.updateQuery("c")
        let old = scheduler.actions[0]
        updater.updateQuery("co")
        XCTAssertTrue(old.cancelled)
        old.action() // Deliberately deliver cancelled work.
        XCTAssertTrue(service.suggestionCalls.isEmpty)
        scheduler.runLast()
        XCTAssertEqual(service.suggestionCalls[0].text, "co")
    }

    func testLateCompletionCannotStartLookupsForOldText() {
        updater.updateQuery("c")
        scheduler.runLast()
        let old = service.suggestionCalls[0]
        updater.updateQuery("coffee")
        scheduler.runLast()
        old.reply(.success([suggestion("Old")]))
        flushCallbacks()
        XCTAssertTrue(old.cancelled)
        XCTAssertTrue(service.searchCalls.isEmpty)
        service.suggestionCalls[1].reply(.success([suggestion("Coffee")]))
        flushCallbacks()
        XCTAssertEqual(service.searchCalls[0].request.naturalLanguageQuery, "Coffee")
    }

    func testLatePlaceResponseCannotOverwriteSubmittedResultsOrCancelNewSearch() {
        updater.setScope(.anywhere)
        beginTyping([suggestion("Old")])
        let old = service.searchCalls[0]
        updater.updateQuery("New", submitted: true)
        let new = service.searchCalls[1]
        new.reply(.success([item("New", latitude: 51.51)]))
        flushCallbacks()
        old.reply(.success([item("Old", latitude: 51.52)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["New"])
        XCTAssertTrue(old.cancelled)
        XCTAssertFalse(new.cancelled)
    }

    func testCancellationErrorCannotReplaceNewSearch() {
        updater.setScope(.anywhere)
        beginTyping([suggestion("Old")])
        let old = service.searchCalls[0]
        old.onCancel = { old.reply(.failure(URLError(.cancelled))) }
        updater.updateQuery("new", submitted: true)
        flushCallbacks()
        guard case .loading? = delegate.states.last else { return XCTFail("Cancellation replaced loading") }
        XCTAssertFalse(service.searchCalls[1].cancelled)
        old.onCancel = nil
    }

    func testSubmitBypassesDebounceAndAcceptsDistantPlaces() {
        updater.setScope(.anywhere)
        updater.updateQuery("Lon")
        updater.updateQuery("Sydney", submitted: true)
        XCTAssertTrue(scheduler.actions[0].cancelled)
        XCTAssertTrue(service.suggestionCalls.isEmpty)
        XCTAssertEqual(service.searchCalls.count, 1)
        let request = service.searchCalls[0].request
        XCTAssertEqual(request.naturalLanguageQuery, "Sydney")
        if #available(iOS 18.0, *) { XCTAssertEqual(request.regionPriority, .default) }
        service.searchCalls[0].reply(.success([item("Sydney", latitude: -33.87, longitude: 151.21)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Sydney"])
    }

    func testTypingFiltersByRadiusAndKeepsAllDistinctValidPlacesSorted() {
        beginTyping([suggestion("Cafe")])
        let inside = CLLocationCoordinate2D(latitude: 51.5 + 24_990 / 111_250, longitude: -0.1)
        let outside = CLLocationCoordinate2D(latitude: 51.5 + 25_100 / 111_250, longitude: -0.1)
        XCTAssertLessThan(CLLocation(latitude: inside.latitude, longitude: inside.longitude).distance(from: center), 25_000)
        XCTAssertGreaterThan(CLLocation(latitude: outside.latitude, longitude: outside.longitude).distance(from: center), 25_000)
        let near = item("Near", latitude: 51.501)
        let unnamed = MKMapItem(placemark: MKPlacemark(coordinate: center.coordinate))
        unnamed.name = ""
        service.searchCalls[0].reply(.success([
            item("Inside", latitude: inside.latitude), near, near,
            item("Outside", latitude: outside.latitude),
            item("Sydney", latitude: -33.87, longitude: 151.21), unnamed,
            item("Invalid", latitude: 100)
        ]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Near", "Inside"])
        let request = service.searchCalls[0].request
        if #available(iOS 18.0, *) { XCTAssertEqual(request.regionPriority, .required) }
    }

    func testNearbyShowsNoResultsWhenAllMatchesAreDistant() {
        beginTyping([suggestion("Sydney")])
        service.searchCalls[0].reply(.success([item("Sydney", latitude: -33.87, longitude: 151.21)]))
        flushCallbacks()
        guard case .noResults? = delegate.states.last else { return XCTFail("Expected no local matches") }
    }

    func testLimitsDistinctCompletionsToFiveAndParallelLookupsToTwo() {
        let first = suggestion("Cafe")
        beginTyping([first, first] + (1...7).map { suggestion("Cafe \($0)") })
        XCTAssertEqual(service.searchCalls.count, 2)
        for index in 0..<5 {
            service.searchCalls[index].reply(.success([]))
            flushCallbacks()
            XCTAssertEqual(service.searchCalls.count, min(5, index + 3))
        }
        XCTAssertEqual(service.searchCalls.map { $0.request.naturalLanguageQuery },
                       ["Cafe", "Cafe 1", "Cafe 2", "Cafe 3", "Cafe 4"])
        guard case .noResults? = delegate.states.last else { return XCTFail("Expected no results") }
    }

    func testSuccessfulPlacesSurviveAnotherResolutionFailure() {
        beginTyping([suggestion("One"), suggestion("Two")])
        service.searchCalls[0].reply(.success([item("One", latitude: 51.51)]))
        service.searchCalls[1].reply(.failure(NSError(domain: MKError.errorDomain, code: Int(MKError.serverFailure.rawValue))))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["One"])
    }

    func testAllFailedLookupsShowFailureButNoMatchesShowsNoResults() {
        beginTyping([suggestion("One")])
        service.searchCalls[0].reply(.failure(NSError(domain: MKError.errorDomain, code: Int(MKError.serverFailure.rawValue))))
        flushCallbacks()
        guard case .failure? = delegate.states.last else { return XCTFail("Expected failure") }
        updater.setScope(.anywhere)
        updater.updateQuery("missing", submitted: true)
        service.searchCalls[1].reply(.failure(NSError(domain: MKError.errorDomain, code: Int(MKError.placemarkNotFound.rawValue))))
        flushCallbacks()
        guard case .noResults? = delegate.states.last else { return XCTFail("Expected no matches") }
    }

    func testCompletionFailureAndEmptyCompletionsAreTerminal() {
        updater.updateQuery("query")
        scheduler.runLast()
        service.suggestionCalls[0].reply(.failure(NSError(domain: MKError.errorDomain, code: Int(MKError.serverFailure.rawValue))))
        flushCallbacks()
        guard case .failure? = delegate.states.last else { return XCTFail("Expected failure") }
        updater.updateQuery("query")
        scheduler.runLast()
        service.suggestionCalls[1].reply(.success([]))
        flushCallbacks()
        guard case .noResults? = delegate.states.last else { return XCTFail("Expected no results") }
    }

    func testClearingAndCancellingIgnoreLateResponses() {
        beginTyping([suggestion("One")])
        let old = service.searchCalls[0]
        updater.updateQuery(" \n ")
        old.reply(.success([item("Old", latitude: 51.51)]))
        flushCallbacks()
        guard case .idle? = delegate.states.last else { return XCTFail("Expected idle") }
        beginTyping([suggestion("Two")])
        let late = service.searchCalls[1]
        updater.searchBarCancelButtonClicked(UISearchBar())
        XCTAssertTrue(delegate.wasCancelled)
        guard case .idle? = delegate.states.last else { return XCTFail("Expected idle after cancellation") }
        let count = delegate.states.count
        late.reply(.success([item("Late", latitude: 51.51)]))
        flushCallbacks()
        XCTAssertEqual(delegate.states.count, count)
        XCTAssertTrue(late.cancelled)
    }

    func testLocationIsRequiredOnlyForNearbyAndArrivalRetriesTheQuery() {
        resetSearch(location: nil)
        updater.updateQuery("query")
        guard case .locationUnavailable? = delegate.states.last else { return XCTFail("Expected location state") }
        XCTAssertTrue(service.suggestionCalls.isEmpty)
        updater.updateLocation(center)
        scheduler.runLast()
        XCTAssertEqual(service.suggestionCalls[0].text, "query")

        resetSearch(location: nil)
        updater.setScope(.anywhere)
        beginTyping([suggestion("Thailand")])
        service.searchCalls[0].reply(.success([item("Thailand", latitude: 13.75, longitude: 100.5)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Thailand"])
        guard case .places(_, let location)? = delegate.states.last else { return XCTFail("Expected places") }
        XCTAssertNil(location)

        updater.updateQuery("Sydney", submitted: true)
        service.searchCalls[1].reply(.success([item("Sydney", latitude: -33.87, longitude: 151.21)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Sydney"])
    }

    func testGoingOfflineStopsSearchAtEachStage() {
        for stage in OfflineStage.allCases {
            resetSearch(location: center)
            switch stage {
            case .beforeQuery:
                online = false
                updater.updateQuery("query")
            case .debounce:
                updater.updateQuery("query")
                online = false
                scheduler.runLast()
            case .completion:
                updater.updateQuery("query")
                scheduler.runLast()
                online = false
                service.suggestionCalls[0].reply(.success([suggestion("One")]))
                flushCallbacks()
            case .resolution:
                beginTyping([suggestion("One"), suggestion("Two"), suggestion("Three")])
                online = false
                service.searchCalls[0].reply(.success([item("One", latitude: 51.51)]))
                flushCallbacks()
                XCTAssertTrue(service.searchCalls[1].cancelled)
                service.searchCalls[1].reply(.success([item("Two", latitude: 51.52)]))
                flushCallbacks()
            }
            guard case .offline? = delegate.states.last else {
                XCTFail("Expected offline at \(stage)")
                continue
            }
            XCTAssertEqual(service.searchCalls.count, stage == .resolution ? 2 : 0, "Stage: \(stage)")
        }
    }

    func testNoResultsShowsScopeGuidanceInsteadOfRecentPlaces() {
        let controller = SearchResultsTableViewController(style: .plain)
        controller.loadViewIfNeeded()
        controller.searchResultsDidUpdate(.idle)
        flushCallbacks()
        XCTAssertTrue(controller.isPresentingDefaultResults)
        controller.searchResultsDidUpdate(.noResults)
        flushCallbacks()
        XCTAssertFalse(controller.isPresentingDefaultResults)
        XCTAssertEqual((controller.tableView.tableHeaderView as? UILabel)?.text,
                       GDLocalizedString("search.no_results_found_nearby"))
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 0)
        controller.searchResultsUpdater.setScope(.anywhere)
        controller.searchResultsDidUpdate(.noResults)
        flushCallbacks()
        XCTAssertFalse(controller.isPresentingDefaultResults)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 0)
        XCTAssertEqual((controller.tableView.tableHeaderView as? UILabel)?.text,
                       GDLocalizedString("search.no_results_found_with_hint"))
    }

    func testNearbySubmitKeepsDisplayedMatchesWithoutStartingAnotherSearch() {
        updater.updateQuery("th")
        scheduler.runLast()
        service.suggestionCalls[0].reply(.success([suggestion("The Crown")]))
        flushCallbacks()
        service.searchCalls[0].reply(.success([item("The Crown", latitude: 51.51)]))
        flushCallbacks()
        let controller = UISearchController(searchResultsController: nil)
        controller.searchBar.text = "th"
        updater.searchBarSearchButtonClicked(controller.searchBar)
        updater.updateSearchResults(for: controller) // Ending editing must not restart the search.
        XCTAssertEqual(delegate.placeNames, ["The Crown"])
        XCTAssertEqual(service.searchCalls.count, 1)
        XCTAssertEqual(service.suggestionCalls.count, 1)
        XCTAssertFalse(service.searchCalls[0].cancelled)
    }

    func testNearbySubmitFlushesDebounceOnceAndKeepsInFlightResolution() {
        updater.updateQuery("th")
        let pending = scheduler.actions[0]
        updater.updateQuery("th", submitted: true)
        XCTAssertTrue(pending.cancelled)
        XCTAssertEqual(service.suggestionCalls.count, 1)
        XCTAssertTrue(service.suggestionCalls[0].nearbyOnly)
        pending.action() // A late cancelled debounce must not start a second operation.
        XCTAssertEqual(service.suggestionCalls.count, 1)
        service.suggestionCalls[0].reply(.success([suggestion("The Crown")]))
        flushCallbacks()
        updater.updateQuery("th", submitted: true)
        XCTAssertFalse(service.searchCalls[0].cancelled)
        service.searchCalls[0].reply(.success([item("The Crown", latitude: 51.51)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["The Crown"])
    }

    func testAnywhereTypingAllowsDistantPlacesAndContinuesResolutionQueue() {
        updater.setScope(.anywhere)
        beginTyping([suggestion("Thailand"), suggestion("One"), suggestion("Two")])
        XCTAssertFalse(service.suggestionCalls[0].nearbyOnly)
        if #available(iOS 18.0, *) { XCTAssertEqual(service.searchCalls[0].request.regionPriority, .default) }
        service.searchCalls[0].reply(.success([item("Thailand", latitude: 13.75, longitude: 100.5)]))
        flushCallbacks()
        XCTAssertEqual(service.searchCalls.count, 3)
        service.searchCalls[1].reply(.success([]))
        service.searchCalls[2].reply(.success([]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Thailand"])
    }

    func testScopeSwitchCancelsOldLookupAndReusesCurrentSubmittedText() {
        updater.updateQuery("th", submitted: true)
        service.suggestionCalls[0].reply(.success([suggestion("The Crown")]))
        flushCallbacks()
        let old = service.searchCalls[0]
        updater.setScope(.anywhere)
        XCTAssertTrue(old.cancelled)
        XCTAssertEqual(service.searchCalls[1].request.naturalLanguageQuery, "th")
        old.reply(.success([item("The Crown", latitude: 51.51)]))
        flushCallbacks()
        guard case .loading? = delegate.states.last else { return XCTFail("Old scope replaced current search") }
        service.searchCalls[1].reply(.success([item("Thailand", latitude: 13.75, longitude: 100.5)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Thailand"])
        updater.setScope(.nearby)
        XCTAssertTrue(service.suggestionCalls.last!.nearbyOnly)
        guard case .loading? = delegate.states.last else { return XCTFail("Expected a fresh nearby lookup") }
        XCTAssertEqual(service.searchCalls.count, 2)
    }

    func testSearchScreenDefaultsToNearbyAndRoutesScopeChanges() {
        guard let navigation = SearchResultsTableViewController.instantiateStandaloneConfiguration(),
              let results = navigation.viewControllers.first as? SearchResultsTableViewController,
              let controller = results.navigationItem.searchController else {
            return XCTFail("Could not construct the search screen")
        }
        XCTAssertEqual(controller.searchBar.scopeButtonTitles,
                       [GDLocalizedString("search.scope.nearby"), GDLocalizedString("search.scope.anywhere")])
        XCTAssertTrue(controller.searchBar.showsScopeBar)
        XCTAssertEqual(controller.searchBar.selectedScopeButtonIndex, 0)
        results.loadViewIfNeeded()
        results.searchResultsDidUpdate(.loading)
        flushCallbacks()
        XCTAssertNil(results.tableView.tableHeaderView, "Loading must not show the empty-results header")
        controller.searchBar.selectedScopeButtonIndex = 1
        controller.searchBar.delegate?.searchBar?(controller.searchBar, selectedScopeButtonIndexDidChange: 1)
        XCTAssertEqual(results.searchResultsUpdater.scope, .anywhere)
    }

    private enum OfflineStage: CaseIterable {
        case beforeQuery, debounce, completion, resolution
    }

    private func resetSearch(location: CLLocation?) {
        updater?.cancel()
        online = true
        service = FakeSearchService()
        scheduler = FakeSearchScheduler()
        delegate = SearchDelegate()
        updater = SearchResultsUpdater(service: service, scheduler: scheduler, location: location,
                                       isOnline: { [unowned self] in self.online })
        updater.delegate = delegate
    }

    private func beginTyping(_ suggestions: [SearchSuggestion]) {
        updater.updateQuery("query")
        scheduler.runLast()
        service.suggestionCalls.last!.reply(.success(suggestions))
        flushCallbacks()
    }

    private func suggestion(_ text: String) -> SearchSuggestion {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        return SearchSuggestion(title: text, subtitle: "", request: request)
    }

    private func item(_ name: String, latitude: Double, longitude: Double = -0.1) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        item.name = name
        return item
    }

    private func flushCallbacks() {
        let drained = expectation(description: "Main queue callbacks")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }
}

private final class FakeSearchService: PlaceSearchService {
    final class SuggestionCall: SearchCancellation {
        let text: String
        let region: MKCoordinateRegion?
        let nearbyOnly: Bool
        let reply: (Result<[SearchSuggestion], Error>) -> Void
        var cancelled = false
        init(text: String, region: MKCoordinateRegion?, nearbyOnly: Bool, reply: @escaping (Result<[SearchSuggestion], Error>) -> Void) {
            self.text = text
            self.region = region
            self.nearbyOnly = nearbyOnly
            self.reply = reply
        }
        func cancel() { cancelled = true }
    }
    final class SearchCall: SearchCancellation {
        let request: MKLocalSearch.Request
        let reply: (Result<[MKMapItem], Error>) -> Void
        var cancelled = false
        var onCancel: (() -> Void)?
        init(request: MKLocalSearch.Request, reply: @escaping (Result<[MKMapItem], Error>) -> Void) {
            self.request = request
            self.reply = reply
        }
        func cancel() {
            cancelled = true
            onCancel?()
        }
    }
    var suggestionCalls: [SuggestionCall] = []
    var searchCalls: [SearchCall] = []
    func suggestions(for text: String, region: MKCoordinateRegion?, nearbyOnly: Bool,
                     completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) -> SearchCancellation {
        let call = SuggestionCall(text: text, region: region, nearbyOnly: nearbyOnly, reply: completion)
        suggestionCalls.append(call)
        return call
    }
    func search(_ request: MKLocalSearch.Request,
                completion: @escaping (Result<[MKMapItem], Error>) -> Void) -> SearchCancellation {
        let call = SearchCall(request: request, reply: completion)
        searchCalls.append(call)
        return call
    }
}

private final class FakeSearchScheduler: SearchScheduler {
    final class Action: SearchCancellation {
        let action: () -> Void
        var cancelled = false
        init(action: @escaping () -> Void) {
            self.action = action
        }
        func cancel() { cancelled = true }
    }
    var actions: [Action] = []
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> SearchCancellation {
        let scheduled = Action(action: action)
        actions.append(scheduled)
        return scheduled
    }
    func runLast() { actions.last!.action() }
}

private final class SearchDelegate: SearchResultsUpdaterDelegate {
    var states: [SearchResultsState] = []
    var isPresentingDefaultResults = false
    var telemetryContext = ""
    var isCachingRequired = false
    var wasCancelled = false
    var placeNames: [String] {
        guard case .places(let places, _)? = states.last else { return [] }
        return places.map(\.name)
    }
    func searchResultsDidUpdate(_ state: SearchResultsState) { states.append(state) }
    func searchWasCancelled() { wasCancelled = true }
}
