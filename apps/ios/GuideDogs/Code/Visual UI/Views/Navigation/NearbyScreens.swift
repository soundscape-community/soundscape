// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Combine
import CoreLocation
import SwiftUI

struct NearbyFiltersScreen: View {
    let navigation: AppNavigationModel
    @State private var context = NearbyDataContext()

    var body: some View {
        NearbyFiltersContent(context: context) { filter in
            navigation.open(.nearbyResults(filter.type?.rawValue))
        }
        .navigationTitle(GDLocalizedString("search.nearby.screen_title"))
        .toolbar(.visible, for: .navigationBar)
    }
}

struct NearbyFiltersContent: View {
    let context: NearbyDataContext
    let select: (NearbyTableFilter) -> Void

    var body: some View {
        VStack(spacing: 0) {
            NavigationBanner(isNearby: true)
            List(context.data.value.filters, id: \.type) { filter in
                Button {
                    select(filter)
                } label: {
                    NearbyFilterLabel(filter: filter)
                }
                .listRowBackground(Color("Background 2"))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color("Background Base"))
        }
    }
}

struct NearbyResultsScreen: View {
    let navigation: AppNavigationModel
    let initialFilter: String?
    @State private var context = NearbyDataContext()

    var body: some View {
        NearbyResultsContent(
            context: context,
            initialFilter: initialFilter.flatMap(PrimaryType.init(rawValue:)),
            allowsActions: true,
            select: { show($0) },
            perform: { show($1, action: $0) }
        )
        .navigationTitle(GDLocalizedString("search.nearby.screen_title"))
        .toolbar(.visible, for: .navigationBar)
    }

    private func show(_ place: POI, action: LocationAction? = nil) {
        navigation.showLocation(LocationDetail(entity: place, telemetryContext: "nearby_places"), action: action)
    }
}

struct NearbyResultsContent: View {
    let context: NearbyDataContext
    let allowsActions: Bool
    let select: (POI) -> Void
    let perform: (LocationAction, POI) -> Void
    @State private var data: NearbyData
    @State private var filter: PrimaryType?
    @State private var showsFilters = false

    init(context: NearbyDataContext, initialFilter: PrimaryType?, allowsActions: Bool,
         select: @escaping (POI) -> Void, perform: @escaping (LocationAction, POI) -> Void) {
        self.context = context
        self.allowsActions = allowsActions
        self.select = select
        self.perform = perform
        _data = State(initialValue: context.data.value)
        _filter = State(initialValue: initialFilter)
    }

    private var places: [POI] {
        guard let location = context.location else { return Array(data.pois.prefix(50)) }
        let predicate = filter.map { Filter.type(expected: $0) }
        return data.pois.sorted(by: Sort.distance(origin: location), filteredBy: predicate, maxLength: 50)
    }

    var body: some View {
        let selected = NearbyTableFilter(type: filter)
        VStack(spacing: 0) {
            NavigationBanner(isNearby: true)
            List {
                Section {
                    ForEach(places, id: \.key) { place in
                        Button {
                            select(place)
                        } label: {
                            PlaceResultLabel(place: place, location: context.location)
                        }
                        .listRowBackground(Color("Background 2"))
                        .accessibilityHint(GDLocalizedTextView("location.select.hint"))
                        .accessibilityActions {
                            if allowsActions {
                                ForEach(LocationAction.enabledAccessibilityActions(for: place), id: \.accessibilityIdentifier) { action in
                                    Button(action.text) { perform(action, place) }
                                }
                            }
                        }
                    }
                    if places.isEmpty {
                        Text(GDLocalizedString("poi_screen.loading_title.no_places_matching", selected.localizedString))
                            .foregroundStyle(Color("Foreground 3"))
                            .padding(.vertical)
                            .listRowBackground(Color("Background Base"))
                    }
                } header: {
                    HStack {
                        Text(selected.localizedString).foregroundStyle(Color("Foreground 3"))
                        Spacer()
                        if filter == nil {
                            Button(GDLocalizedString("filter.alert_title")) { showsFilters = true }
                                .disabled(data.pois.isEmpty)
                        } else {
                            Button(GDLocalizedString("filter.clear.capital")) { filter = nil }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color("Background Base"))
            .environment(\.colorScheme, .dark)
        }
        .confirmationDialog(GDLocalizedString("filter.alert_title"), isPresented: $showsFilters) {
            ForEach(data.filters, id: \.type) { choice in
                Button(choice.localizedString) { filter = choice.type }
            }
        }
        .onReceive(context.data.catch { _ in Empty<NearbyData, Never>() }.receive(on: RunLoop.main)) { value in
            data = value
        }
    }
}

private struct NearbyFilterLabel: View {
    let filter: NearbyTableFilter

    var body: some View {
        HStack {
            if let image = filter.image {
                Image(uiImage: image).accessibilityHidden(true)
            }
            Text(filter.localizedString)
                .foregroundStyle(Color("Foreground 1"))
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("Foreground 3"))
                .accessibilityHidden(true)
        }
    }
}

struct PlaceResultLabel: View {
    let place: POI
    let location: CLLocation?

    private var marker: ReferenceEntity? {
        guard let value = SpatialDataCache.referenceEntityByEntityKey(place.key), !value.isTemp else { return nil }
        return value
    }

    var body: some View {
        let marker = marker
        HStack(spacing: 12) {
            Image(marker == nil ? "ic_place_white" : "ic_markers_28px")
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: marker?.name ?? place.localizedName)
                    .accessibilityLabel(Text(verbatim: spokenName(for: marker)))
                if let location {
                    let distance = place.distanceToClosestLocation(from: location)
                    let direction = CardinalDirection(direction: place.bearingToClosestLocation(from: location))
                    let short = direction.map { "・" + $0.localizedAbbreviatedString } ?? ""
                    let spoken = direction.map { " " + $0.localizedString } ?? ""
                    if distance >= 0 {
                        Text(verbatim: LanguageFormatter.string(from: distance, abbreviated: true) + short)
                            .font(.footnote)
                            .foregroundStyle(Color("Highlight Yellow"))
                            .accessibilityLabel(Text(verbatim: LanguageFormatter.spellOutDistance(distance) + spoken))
                    }
                }
                if let address = marker?.displayAddress ?? place.addressLine {
                    Text(verbatim: address)
                        .font(.footnote)
                        .foregroundStyle(Color("Foreground 3"))
                }
            }
        }
        .foregroundStyle(Color("Foreground 1"))
        .accessibilityElement(children: .combine)
    }

    private func spokenName(for marker: ReferenceEntity?) -> String {
        guard let marker else { return place.localizedName }
        if SpatialDataCache.isAddress(poi: marker.getPOI()) && marker.nickname == nil {
            return GDLocalizedString("markers.generic_name")
        }
        return GDLocalizedString("markers.marker_with_name", marker.name)
    }
}
