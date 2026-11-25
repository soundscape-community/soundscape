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

    func openMenuDestination(_ item: MenuItem) {
        let route: AppRoute
        switch item {
        case .recreation: route = .recreation
        case .gpxRecording: route = .gpxRecording
        case .devices: route = .devices
        case .status: route = .troubleshooting
        case .help: route = .help
        case .settings: route = .settings
        case .home, .feedback, .rate, .share: return
        }
        AppNavigationModel.shared.open(route)
    }
    var saveCurrentLocation: () -> Void = {}
    let card = UIView()
    let callouts = UIView()
    let largeBanner = UIView()
    let smallBanner = UIView()
}

struct HomeView: View {
    @ObservedObject var layout: HomeLayout

    var body: some View {
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
        .background {
            Color("Background Base").ignoresSafeArea()
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
