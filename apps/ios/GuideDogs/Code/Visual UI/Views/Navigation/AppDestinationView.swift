// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI
import UIKit

struct AppDestinationView: View {
    let route: AppRoute
    @ObservedObject var navigation: AppNavigationModel

    var body: some View {
        switch route {
        case .permission(let service):
            RequiredPermissionView(service: service) {
                navigation.close(route)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        case .recreation:
            LegacyNavigationScreen { AuthoredActivitiesListHostingController() }
        case .gpxRecording:
            LegacyNavigationScreen { GPXRecordingHostingController() }
        case .settings:
            SettingsScreen(navigation: navigation)
        case .devices:
            devices
        case .troubleshooting:
            LegacyNavigationScreen { TroubleshootingViewController() }
        case .help:
            HelpView(navigation: navigation)
        case .helpPage(let page):
            HelpView(navigation: navigation, route: page)
        case .settingsPage(let page):
            settingsPage(page)
        case .nearby:
            NearbyFiltersScreen(navigation: navigation)
        case .nearbyResults(let filter):
            NearbyResultsScreen(navigation: navigation, initialFilter: filter)
        case .location(let id):
            if let detail = navigation.locations[id] {
                LegacyNavigationScreen {
                    let controller = LocationDetailViewController()
                    controller.locationDetail = detail
                    controller.deleteAction = .perform { navigation.close(route) }
                    controller.initialAction = { navigation.takeAction(forLocation: id) }
                    controller.returnToHome = { navigation.returnHome(focusOnBeacon: $0) }
                    return controller
                }
            }
        case .activeRoute:
            LegacyNavigationScreen { RouteDetailsViewHostingController.makeForActiveRoute() ?? UIViewController() }
        case .editor(let id):
            if let destination = navigation.editors[id] {
                LegacyNavigationScreen { destination.makeViewController() ?? UIViewController() }
            }
        case .markers:
            LegacyNavigationScreen { MarkersAndRoutesListHostViewController() }
        }
    }

    @ViewBuilder
    private func settingsPage(_ route: SettingsRoute) -> some View {
        switch route {
        case .language:
            LanguageSettingsView()
                .navigationTitle(GDLocalizedString("settings.language.screen_title.2"))
                .toolbar(.visible, for: .navigationBar)
        case .voice:
            VoiceSettingsView()
                .navigationTitle(GDLocalizedString("settings.general.voice"))
                .toolbar(.visible, for: .navigationBar)
        case .volume:
            VolumeControls().navigationTitle(GDLocalizedString("general.volume"))
                .toolbar(.visible, for: .navigationBar)
        case .devices:
            devices
        case .troubleshooting:
            LegacyNavigationScreen { TroubleshootingViewController() }
        case .shortcuts:
            LegacyNavigationScreen { SiriShortcutsTableViewController() }
        case .beacon:
            BeaconSelectionView().navigationTitle(GDLocalizedString("beacon.audio_beacon"))
                .toolbar(.visible, for: .navigationBar)
        case .about:
            AboutScreen(navigation: navigation)
        case .versionHistory:
            VersionHistoryScreen()
        case .notices:
            LegacyNavigationScreen { ThirdPartyNoticesViewController() }
        }
    }

    private var devices: some View {
        LegacyNavigationScreen {
            let controller = DevicesViewController()
            controller.onReturnHome = { navigation.returnHome() }
            return controller
        }
    }
}

/// Hosts a UIKit flow with its own push behavior. Its first Back returns to the SwiftUI stack.
struct LegacyNavigationScreen: View {
    @Environment(\.dismiss) private var dismiss
    let makeController: () -> UIViewController

    var body: some View {
        Container(makeController: makeController, back: { dismiss() })
            .toolbar(.hidden, for: .navigationBar)
    }

    private struct Container: UIViewControllerRepresentable {
        let makeController: () -> UIViewController
        let back: () -> Void

        func makeUIViewController(context: Context) -> NavigationController {
            let navigation = EmbeddedNavigationController()
            navigation.back = back
            let root = makeController()
            let item = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), primaryAction: UIAction { _ in back() })
            item.accessibilityLabel = GDLocalizedString("ui.back_button.title")
            root.navigationItem.leftBarButtonItem = item
            (root as? DevicesViewController)?.coordinatorBackButton = item
            navigation.setViewControllers([root], animated: false)
            return navigation
        }

        func updateUIViewController(_ controller: NavigationController, context: Context) {}
    }

    final class EmbeddedNavigationController: NavigationController {
        var back: () -> Void = {}

        override func popViewController(animated: Bool) -> UIViewController? {
            if viewControllers.count == 1 {
                back()
                return nil
            }
            return super.popViewController(animated: animated)
        }
    }
}

struct HelpOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = OnboardingViewModel()

    var body: some View {
        OnboardingWelcomeView(context: .help)
            .environmentObject(model)
            .onAppear { model.dismiss = { dismiss() } }
    }
}
