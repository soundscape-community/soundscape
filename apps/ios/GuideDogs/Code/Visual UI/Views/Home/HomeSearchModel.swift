// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import CoreLocation
import SwiftUI
import UIKit

final class HomeSearchModel: ObservableObject, SearchResultsUpdaterDelegate {
    let results = SearchResultsModel()
    @Published private(set) var isActive = false
    @Published private(set) var query = ""

    var onSelect: (POI) -> Void = { _ in }
    var onAction: (LocationAction, LocationDetail) -> Void = { _, _ in }

    var isPresentingDefaultResults: Bool {
        if case .recent = results.content { return true }
        return false
    }

    let telemetryContext = "home_screen"
    let isCachingRequired = false

    private lazy var updater: SearchResultsUpdater = {
        let updater = SearchResultsUpdater()
        updater.delegate = self
        return updater
    }()
    private var announcement: DispatchWorkItem?
    private var pendingAction: UUID?

    func begin() {
        guard !isActive else { return }
        results.allowsActions = true
        results.reloadRecent()
        results.content = .recent
        results.showsEmptyMessage = false
        isActive = true
        NSUserActivity(userAction: .search).becomeCurrent()
    }

    func search(_ text: String) {
        guard isActive, query != text else { return }
        query = text
        updater.update(query: text, context: .partialSearchText)
    }

    func submit(_ text: String) {
        guard isActive, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        query = text
        updater.update(query: text, context: .completeSearchText)
    }

    func searchWasCancelled() {
        guard isActive else { return }
        isActive = false
        query = ""
        announcement?.cancel()
        updater.cancel()
        pendingAction = nil
        results.isResolvingPlace = false
    }

    func select(_ place: POI) {
        if !isPresentingDefaultResults {
            LocationDetail(entity: place).updateLastSelectedDate()
        }
        searchWasCancelled()
        onSelect(place)
    }

    func perform(_ action: LocationAction, on place: POI) {
        let detail = LocationDetail(entity: place, telemetryContext: "\(telemetryContext).search_results")
        let request = UUID()
        pendingAction = request
        results.isResolvingPlace = true
        LocationDetail.fetchNameAndAddressIfNeeded(for: detail) { [weak self] detail in
            DispatchQueue.main.async {
                guard let self, self.pendingAction == request else { return }
                self.searchWasCancelled()
                self.onAction(action, detail)
            }
        }
    }

    func searchResultsDidStartUpdating() {
        if AppContext.shared.offlineContext.state == .online {
            update(.searching)
        } else {
            update(.offline, announcement: GDLocalizedString("searching.offline"))
        }
    }

    func searchResultsDidUpdate(_ places: [POI], searchLocation: CLLocation?) {
        if let first = places.first {
            update(.results(places, searchLocation), announcement: GDLocalizedString(
                "search.results_found_first_result", String(places.count), first.localizedName
            ))
        } else {
            update(.recent)
        }
    }

    func searchResultsDidUpdate(_ searchForMore: String?) {
        update(.noResults(searchForMore), announcement: GDLocalizedString(
            searchForMore == nil ? "search.no_results_found_with_hint" : "search.no_results_found_with_action"
        ))
    }

    private func update(_ content: SearchResultsModel.Content, announcement message: String? = nil) {
        guard isActive else { return }
        announcement?.cancel()
        results.content = content
        if let message {
            let announcement = DispatchWorkItem {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            self.announcement = announcement
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: announcement)
        }
    }
}
