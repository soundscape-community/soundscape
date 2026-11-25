// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI
import UIKit

enum HomeBrowseDestination {
    case nearby, markers, currentLocation

    var title: String {
        switch self {
        case .nearby: return "search.nearby.screen_title"
        case .markers: return "search.view_markers"
        case .currentLocation: return "search.use_current_location"
        }
    }

    var hint: String {
        switch self {
        case .nearby: return "search.button.nearby.accessibility_hint"
        case .markers: return "search.button.markers.accessibility_hint"
        case .currentLocation: return "search.button.current_location.accessibility_hint"
        }
    }
}

final class HomeLayout: ObservableObject {
    @Published var showsBrowse = true
    @Published var showsMenu = false
    let search = HomeSearchModel()
    private var menuAction: (() -> Void)?

    var beginStandby: () -> Void = {}
    var sendFeedback: () -> Void = {}
    @Published var isSavingCurrentLocation = false
    @Published var cardHeight: CGFloat = 215
    @Published var calloutHeight: CGFloat = 141
    @Published var largeBannerHeight: CGFloat = 0
    @Published var smallBannerHeight: CGFloat = 0

    var showCurrentLocation: () -> Void = {}

    func openBrowse(_ destination: HomeBrowseDestination) {
        switch destination {
        case .nearby: AppNavigationModel.shared.open(.nearby)
        case .markers: AppNavigationModel.shared.open(.markers)
        case .currentLocation: showCurrentLocation()
        }
    }

    func dismissMenu(then action: (() -> Void)? = nil) {
        menuAction = action
        showsMenu = false
    }

    func finishMenuDismissal() {
        let action = menuAction
        menuAction = nil
        action?()
    }

    func selectMenuItem(_ item: HomeMenuItem) {
        if let route = item.route {
            dismissMenu { AppNavigationModel.shared.open(route) }
            return
        }
        switch item {
        case .feedback: dismissMenu(then: sendFeedback)
        case .rate: dismissMenu { AppReviewHelper.showWriteReviewPage() }
        case .share: dismissMenu { AppShareHelper.share() }
        default: break
        }
    }

    var saveCurrentLocation: () -> Void = {}
    let card = UIView()
    let callouts = UIView()
    let largeBanner = UIView()
    let smallBanner = UIView()
}

struct HomeView: View {
    @ObservedObject var layout: HomeLayout
    @ObservedObject var search: HomeSearchModel
    @FocusState private var searchFieldFocused: Bool
    @AccessibilityFocusState private var menuButtonFocused: Bool
    @AccessibilityFocusState private var searchAccessibilityFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            homeSurface
                .accessibilityElement(children: .contain)
                .accessibilityHidden(layout.showsMenu)
                .allowsHitTesting(!layout.showsMenu)

            if layout.showsMenu {
                HomeMenuView(close: { layout.dismissMenu() }, select: layout.selectMenuItem)
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                    .onDisappear {
                        guard !layout.showsMenu else { return }
                        // Let the menu finish leaving before pushing a route or opening a system sheet.
                        DispatchQueue.main.async {
                            menuButtonFocused = true
                            layout.finishMenuDismissal()
                        }
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: layout.showsMenu)
        .onChange(of: search.isActive) { active in
            searchFieldFocused = active
            searchAccessibilityFocused = layout.showsBrowse
        }
        .onChange(of: searchFieldFocused) { focused in
            search.results.showsEmptyMessage = !focused
        }
        .onChange(of: layout.showsBrowse) { visible in
            if !visible { search.searchWasCancelled() }
        }
    }

    private var homeSurface: some View {
        VStack(spacing: 0) {
            if !search.isActive {
                controls
            }

            if layout.showsBrowse {
                searchBar
            }

            if search.isActive {
                SearchResultsScreen(
                    model: search.results,
                    select: search.select,
                    selectQuery: submitSearch,
                    perform: { search.perform($0, on: $1) }
                )
            } else {
                homeContent
            }
        }
        .background(Color("Background Base").ignoresSafeArea())
        .accessibilityIgnoresInvertColors()
    }

    private var controls: some View {
        HStack {
            Button {
                layout.showsMenu = true
            } label: {
                Image("menu")
                    .frame(width: 48, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(GDLocalizedTextView("ui.menu"))
            .accessibilityHint(GDLocalizedTextView("ui.menu.hint"))
            .accessibilityFocused($menuButtonFocused)

            Spacer()

            Button(action: layout.beginStandby) {
                Image("sleep_icon")
                    .frame(width: 48, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(GDLocalizedTextView("sleep.sleep"))
            .accessibilityHint(GDLocalizedTextView("sleep.sleep.acc_hint"))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primaryForeground)
        .padding(.horizontal, 12)
    }

    private var searchBar: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)

                TextField(
                    GDLocalizedString("search.choose_destination"),
                    text: Binding(get: { search.query }, set: search.search),
                    prompt: GDLocalizedTextView("search.choose_destination")
                        .foregroundColor(Color.secondaryBackground.opacity(0.8))
                )
                .focused($searchFieldFocused)
                .accessibilityFocused($searchAccessibilityFocused)
                .accessibilityIdentifier("searchbar.home")
                .submitLabel(.search)
                .onSubmit { submitSearch(search.query) }

                if !search.query.isEmpty {
                    Button {
                        search.search("")
                        searchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(GDLocalizedTextView("general.text.clear"))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(Color.secondaryBackground)
            .tint(Color.secondaryBackground)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .environment(\.colorScheme, .dark)

            if search.isActive {
                Button {
                    search.searchWasCancelled()
                } label: {
                    GDLocalizedTextView("general.alert.cancel")
                        .frame(minHeight: 44)
                }
                .foregroundStyle(Color.primaryForeground)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .onChange(of: searchFieldFocused) { focused in
            if focused { search.begin() }
        }
        .accessibilityAction(.escape, search.searchWasCancelled)
    }

    private func submitSearch(_ query: String) {
        searchFieldFocused = false
        search.submit(query)
    }

    private var homeContent: some View {
        VStack(spacing: 0) {
            EmbeddedView(content: layout.largeBanner)
                .frame(height: layout.largeBannerHeight)
                .clipped()
                .accessibilityHidden(layout.largeBannerHeight == 0)

            ScrollView {
                VStack(spacing: 0) {
                    if layout.showsBrowse {
                        browse
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .padding(.bottom, 24)
                    }

                    EmbeddedView(content: layout.smallBanner)
                        .frame(height: layout.smallBannerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(.bottom, layout.showsBrowse ? 8 : 0)
                        .accessibilityHidden(layout.smallBannerHeight == 0)

                    EmbeddedView(content: layout.card)
                        .frame(height: layout.cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }

            EmbeddedView(content: layout.callouts)
                .frame(height: max(layout.calloutHeight, 141))
                .background {
                    Color("Background 2").ignoresSafeArea(edges: .bottom)
                }
        }
    }

    private var browse: some View {
        VStack(spacing: 1) {
            browseButton(.nearby)
            browseButton(.markers)
            browseButton(.currentLocation)
                .accessibilityAction(named: Text(verbatim: LocationAction.save(isEnabled: true).text)) {
                    layout.saveCurrentLocation()
                }
        }
    }

    private func browseButton(_ destination: HomeBrowseDestination) -> some View {
        LocationBrowseButton(destination: destination,
                             showsProgress: destination == .currentLocation && layout.isSavingCurrentLocation) {
            layout.openBrowse(destination)
        }
    }
}

struct LocationBrowseButton: View {
    let destination: HomeBrowseDestination
    var showsProgress = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                GDLocalizedTextView(destination.title)
                Spacer(minLength: 12)
                if showsProgress {
                    ProgressView().tint(Color("Foreground 1"))
                } else {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color("Foreground 1"))
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: Colors.Background.primary ?? .darkGray))
        .accessibilityHint(GDLocalizedTextView(destination.hint))
    }
}
