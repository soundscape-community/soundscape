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
        online = true
        service = FakeSearchService()
        scheduler = FakeSearchScheduler()
        delegate = SearchDelegate()
        updater = SearchResultsUpdater(service: service, scheduler: scheduler, location: center,
                                       isOnline: { [unowned self] in self.online })
        updater.delegate = delegate
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
        XCTAssertEqual(scheduler.actions[0].delay, 0.4)
        scheduler.runLast()
        XCTAssertEqual(service.suggestionCalls[0].text, "c")
        let region = service.suggestionCalls[0].region
        XCTAssertEqual(region.center.latitude, center.coordinate.latitude)
        XCTAssertEqual(region.center.longitude, center.coordinate.longitude)
        XCTAssertEqual(MKMapPoint(region.center).distance(to: MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude))), 25_000, accuracy: 200)
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

    func testCancellationInvalidatesBeforeSynchronousCancellationCallback() {
        beginTyping([suggestion("Old")])
        let old = service.searchCalls[0]
        old.onCancel = { old.reply(.failure(NSError(domain: MKError.errorDomain,
                                                  code: Int(MKError.unknown.rawValue)))) }
        updater.updateQuery("new", submitted: true)
        flushCallbacks()
        guard case .loading? = delegate.states.last else { return XCTFail("Cancellation replaced loading") }
        XCTAssertFalse(service.searchCalls[1].cancelled)
        old.onCancel = nil
    }

    func testSubmitBypassesDebounceAndAcceptsDistantPlaces() {
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

    func testOnlyDistantPlacesShowsSearchForMoreInsteadOfPlaces() {
        beginTyping([suggestion("Sydney")])
        service.searchCalls[0].reply(.success([item("Sydney", latitude: -33.87, longitude: 151.21)]))
        flushCallbacks()
        guard case .noResults(let more)? = delegate.states.last else { return XCTFail("Expected no local matches") }
        XCTAssertEqual(more, "query")
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

    func testCategoryCompletionKeepsItsOriginalRequest() {
        let category = suggestion("coffee")
        beginTyping([category])
        XCTAssertTrue(service.searchCalls[0].request === category.request)
        service.searchCalls[0].reply(.success([item("Coffee One", latitude: 51.51), item("Coffee Two", latitude: 51.52)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Coffee One", "Coffee Two"])
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
        updater.updateQuery("missing", submitted: true)
        service.searchCalls[1].reply(.failure(NSError(domain: MKError.errorDomain, code: Int(MKError.placemarkNotFound.rawValue))))
        flushCallbacks()
        guard case .noResults(let more)? = delegate.states.last else { return XCTFail("Expected no matches") }
        XCTAssertNil(more)
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

    func testClearAndDismissIgnoreLateResponses() {
        beginTyping([suggestion("One")])
        let old = service.searchCalls[0]
        updater.updateQuery(" \n ")
        old.reply(.success([item("Old", latitude: 51.51)]))
        flushCallbacks()
        guard case .idle? = delegate.states.last else { return XCTFail("Expected idle") }
        beginTyping([suggestion("Two")])
        let late = service.searchCalls[1]
        updater.cancel()
        let count = delegate.states.count
        late.reply(.success([item("Late", latitude: 51.51)]))
        flushCallbacks()
        XCTAssertEqual(delegate.states.count, count)
        XCTAssertTrue(late.cancelled)
    }

    func testMissingLocationRetriesTypingWhenLocationArrivesAndAllowsGlobalSubmission() {
        updater = SearchResultsUpdater(service: service, scheduler: scheduler, location: nil, isOnline: { true })
        updater.delegate = delegate
        updater.updateQuery("query")
        guard case .locationUnavailable? = delegate.states.last else { return XCTFail("Expected location state") }
        XCTAssertTrue(scheduler.actions.isEmpty)
        updater.updateLocation(center)
        scheduler.runLast()
        XCTAssertEqual(service.suggestionCalls[0].text, "query")
        updater = SearchResultsUpdater(service: service, scheduler: scheduler, location: nil, isOnline: { true })
        updater.delegate = delegate
        updater.updateQuery("Sydney", submitted: true)
        service.searchCalls[0].reply(.success([item("Sydney", latitude: -33.87, longitude: 151.21)]))
        flushCallbacks()
        XCTAssertEqual(delegate.placeNames, ["Sydney"])
        guard case .places(_, let location)? = delegate.states.last else { return XCTFail("Expected places") }
        XCTAssertNil(location)
    }

    func testOfflineBeforeAndDuringDebounceDoesNotIssueRequests() {
        online = false
        updater.updateQuery("query")
        guard case .offline? = delegate.states.last else { return XCTFail("Expected offline") }
        XCTAssertTrue(scheduler.actions.isEmpty)
        online = true
        updater.updateQuery("query")
        online = false
        scheduler.runLast()
        guard case .offline? = delegate.states.last else { return XCTFail("Expected offline") }
        XCTAssertTrue(service.suggestionCalls.isEmpty)
    }

    func testGoingOfflineDuringResolutionCancelsRemainingWork() {
        beginTyping([suggestion("One"), suggestion("Two"), suggestion("Three")])
        online = false
        service.searchCalls[0].reply(.success([item("One", latitude: 51.51)]))
        flushCallbacks()
        guard case .offline? = delegate.states.last else { return XCTFail("Expected offline") }
        XCTAssertEqual(service.searchCalls.count, 2)
        XCTAssertTrue(service.searchCalls[1].cancelled)
        service.searchCalls[1].reply(.success([item("Two", latitude: 51.52)]))
        flushCallbacks()
        guard case .offline? = delegate.states.last else { return XCTFail("Late result replaced offline") }
    }

    func testGoingOfflineDuringCompletionDoesNotStartLookups() {
        updater.updateQuery("query")
        scheduler.runLast()
        online = false
        service.suggestionCalls[0].reply(.success([suggestion("One")]))
        flushCallbacks()
        guard case .offline? = delegate.states.last else { return XCTFail("Expected offline") }
        XCTAssertTrue(service.searchCalls.isEmpty)
    }

    func testSearchBarCancelRestoresIdleAndCancelsRequest() {
        beginTyping([suggestion("One")])
        updater.searchBarCancelButtonClicked(UISearchBar())
        XCTAssertTrue(service.searchCalls[0].cancelled)
        XCTAssertTrue(delegate.wasCancelled)
        guard case .idle? = delegate.states.last else { return XCTFail("Expected idle") }
    }

    func testSelectingResolvedPlacePreservesEntitySelection() {
        beginTyping([suggestion("One")])
        service.searchCalls[0].reply(.success([item("One", latitude: 51.51)]))
        flushCallbacks()
        guard case .places(let places, _)? = delegate.states.last else { return XCTFail("Expected places") }
        updater.selectSearchResult(places[0]) { result, error in
            XCTAssertNil(error)
            guard case .entity(let poi)? = result else { return XCTFail("Expected entity selection") }
            XCTAssertEqual(poi.name, "One")
            XCTAssertEqual(poi.centroidLatitude, 51.51)
        }
    }

    func testNoResultsUIIsNotRecentPlacesAndShowsGuidanceWhileEditing() {
        let controller = SearchResultsTableViewController(style: .plain)
        controller.loadViewIfNeeded()
        controller.searchResultsDidUpdate(.idle)
        flushCallbacks()
        XCTAssertTrue(controller.isPresentingDefaultResults)
        controller.searchResultsDidUpdate(.noResults(searchForMore: "coffee"))
        flushCallbacks()
        XCTAssertFalse(controller.isPresentingDefaultResults)
        XCTAssertEqual((controller.tableView.tableHeaderView as? UILabel)?.text,
                       GDLocalizedString("search.no_results_found_with_action"))
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 1)
        controller.searchResultsDidUpdate(.noResults(searchForMore: nil))
        flushCallbacks()
        XCTAssertFalse(controller.isPresentingDefaultResults)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 0)
        controller.searchWasCancelled()
        controller.searchResultsDidUpdate(.loading)
        flushCallbacks()
        XCTAssertFalse(controller.wasSearchCancelled)
        XCTAssertNil(controller.tableView.tableHeaderView)
        controller.searchResultsDidUpdate(.locationUnavailable)
        flushCallbacks()
        XCTAssertEqual((controller.tableView.tableHeaderView as? UILabel)?.text,
                       GDLocalizedString("general.error.location_services_find_location_error"))
        controller.searchResultsDidUpdate(.failure)
        flushCallbacks()
        XCTAssertEqual((controller.tableView.tableHeaderView as? UILabel)?.text,
                       GDLocalizedString("general.alert.error.message"))
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
        let region: MKCoordinateRegion
        let reply: (Result<[SearchSuggestion], Error>) -> Void
        var cancelled = false
        init(text: String, region: MKCoordinateRegion, reply: @escaping (Result<[SearchSuggestion], Error>) -> Void) {
            self.text = text
            self.region = region
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
    func suggestions(for text: String, region: MKCoordinateRegion,
                     completion: @escaping (Result<[SearchSuggestion], Error>) -> Void) -> SearchCancellation {
        let call = SuggestionCall(text: text, region: region, reply: completion)
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
        let delay: TimeInterval
        let action: () -> Void
        var cancelled = false
        init(delay: TimeInterval, action: @escaping () -> Void) {
            self.delay = delay
            self.action = action
        }
        func cancel() { cancelled = true }
    }
    var actions: [Action] = []
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> SearchCancellation {
        let scheduled = Action(delay: delay, action: action)
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
