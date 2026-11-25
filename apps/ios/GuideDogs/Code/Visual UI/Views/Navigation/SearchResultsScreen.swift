// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import CoreLocation
import SwiftUI

final class SearchResultsModel: ObservableObject {
    enum Content {
        case recent
        case searching
        case offline
        case noResults(String?)
        case results([POI], CLLocation?)
    }

    @Published var content: Content = .recent
    @Published var isResolvingPlace = false
    @Published var showsEmptyMessage = false
    var allowsActions = false
    var recent: [POI] = []
    var callouts: [POI] = []
    var location: CLLocation?

    func reloadRecent() {
        location = AppContext.shared.geolocationManager.location

        // Initialize recent selections
        let selections = SpatialDataCache.recentlySelectedObjects()

        // Initialize recent callouts
        let recentCallouts: [POI] = AppContext.shared.calloutHistory.callouts
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

        recent = selections
        callouts = recentCallouts
    }
}

struct SearchResultsScreen: View {
    @ObservedObject var model: SearchResultsModel
    let select: (POI) -> Void
    let selectQuery: (String) -> Void
    let perform: (LocationAction, POI) -> Void

    var body: some View {
        List {
            switch model.content {
            case .recent:
                rows(model.recent, location: model.location)
                if !model.callouts.isEmpty {
                    Section {
                        rows(model.callouts, location: model.location)
                    } header: {
                        GDLocalizedTextView("poi_screen.header.recent.callouts")
                            .foregroundStyle(Color("Foreground 3"))
                    }
                }
                if model.recent.isEmpty && model.callouts.isEmpty { emptyMessage }
            case .searching:
                ProgressView { GDLocalizedTextView("search.searching_with_punctuation") }
                    .listRowBackground(Color("Background Base"))
            case .offline:
                GDLocalizedTextView("searching.offline")
                    .listRowBackground(Color("Background Base"))
            case .noResults(let query):
                if let query {
                    Button(GDLocalizedString("search.search_for", query)) { selectQuery(query) }
                        .listRowBackground(Color("Background 2"))
                } else {
                    emptyMessage
                }
            case .results(let places, let location):
                rows(places, location: location, numbered: true)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("Background Base"))
        .environment(\.colorScheme, .dark)
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isResolvingPlace)
        .overlay {
            if model.isResolvingPlace {
                ProgressView()
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var emptyMessage: some View {
        if model.showsEmptyMessage {
            VStack(spacing: 8) {
                GDLocalizedTextView("searching.no_results_found_title").font(.title2)
                GDLocalizedTextView("searching.no_results_found_message")
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .listRowBackground(Color("Background Base"))
        }
    }

    private func rows(_ places: [POI], location: CLLocation?, numbered: Bool = false) -> some View {
        ForEach(Array(places.enumerated()), id: \.offset) { index, place in
            Button {
                select(place)
            } label: {
                PlaceResultLabel(place: place, location: location)
            }
            .listRowBackground(Color("Background 2"))
            .accessibilityHint(Text(verbatim: hint(index: index, count: places.count, numbered: numbered)))
            .accessibilityActions {
                if model.allowsActions {
                    ForEach(LocationAction.enabledAccessibilityActions(for: place), id: \.accessibilityIdentifier) { action in
                        Button(action.text) { perform(action, place) }
                    }
                }
            }
        }
    }

    private func hint(index: Int, count: Int, numbered: Bool) -> String {
        let hint = GDLocalizedString("location.select.hint")
        guard numbered else { return hint }
        return hint + " " + GDLocalizedString("settings.new_feature.num_of_num", String(index + 1), String(count))
    }
}
