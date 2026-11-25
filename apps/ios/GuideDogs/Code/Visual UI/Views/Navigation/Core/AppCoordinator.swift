// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

enum SettingsRoute: String, Hashable {
    case language, voice, volume, devices, shortcuts, beacon, troubleshooting, about, versionHistory, notices
}

enum HelpRoute: Hashable, Identifiable {
    case page(String)
    case answer(String)
    case offline, beaconTutorial, markerTutorial

    var id: String {
        switch self {
        case .page(let key): return "page/" + key
        case .answer(let key): return "answer/" + key
        case .offline: return "offline"
        case .beaconTutorial: return "beacon-tutorial"
        case .markerTutorial: return "marker-tutorial"
        }
    }
}

enum PermissionRoute: String, Hashable {
    case location, motion
}

enum AppRoute: Hashable, Identifiable {
    case settings, help, nearby, markers, devices, troubleshooting
    case recreation, gpxRecording
    case permission(PermissionRoute)
    case nearbyResults(String?)
    case location(String)
    case activeRoute, editor(String)
    case settingsPage(SettingsRoute)
    case helpPage(HelpRoute)

    var id: String {
        switch self {
        case .settings: return "settings"
        case .help: return "help"
        case .nearby: return "nearby"
        case .markers: return "markers"
        case .devices: return "devices"
        case .recreation: return "recreation"
        case .gpxRecording: return "gpx-recording"
        case .permission(let service): return "permission/" + service.rawValue
        case .troubleshooting: return "troubleshooting"
        case .nearbyResults(let filter): return filter.map { "nearby/filter/" + $0 } ?? "nearby/all"
        case .location(let id): return "location/" + id
        case .activeRoute: return "active-route"
        case .editor(let id): return "editor/" + id
        case .settingsPage(let page): return "settings/" + page.rawValue
        case .helpPage(let page): return "help/" + page.id
        }
    }
}

enum AppNavigationIntent: Hashable {
    case search, saveMarker, streetPreview
}

struct AppCoordinator {
    enum Stage: Equatable {
        case starting, onboarding, telemetryConsent, home
    }

    private(set) var stage: Stage = .starting
    private(set) var path: [AppRoute] = []
    private(set) var isShowingHelpTutorial = false
    private(set) var isHomeReady = false
    private(set) var isShowingNewFeatures = false
    private var pendingIntent: AppNavigationIntent?

    mutating func finishLaunch(needsOnboarding: Bool, needsConsent: Bool) {
        guard stage == .starting else { return }
        if needsOnboarding {
            stage = .onboarding
        } else {
            stage = needsConsent ? .telemetryConsent : .home
        }
    }

    mutating func finishOnboarding() {
        guard stage == .onboarding else { return }
        stage = .home
    }

    mutating func finishConsent() {
        guard stage == .telemetryConsent else { return }
        stage = .home
    }

    mutating func open(_ route: AppRoute) {
        guard stage == .home, path.last != route else { return }
        path.append(route)
    }

    mutating func updatePath(_ path: [AppRoute]) {
        guard stage == .home else { return }
        self.path = path
    }

    mutating func close(_ route: AppRoute) {
        guard path.last == route else { return }
        path.removeLast()
    }

    mutating func setHelpTutorialPresented(_ presented: Bool) {
        guard !presented || path.contains(.help) else { return }
        isShowingHelpTutorial = presented
    }

    mutating func setNewFeaturesPresented(_ presented: Bool) {
        guard !presented || (stage == .home && path.isEmpty) else { return }
        isShowingNewFeatures = presented
    }

    mutating func receive(_ intent: AppNavigationIntent) -> AppNavigationIntent? {
        if isHomeReady { return intent }
        pendingIntent = intent
        return nil
    }

    mutating func homeBecameReady() -> AppNavigationIntent? {
        guard stage == .home else { return nil }
        isHomeReady = true
        let intent = pendingIntent
        pendingIntent = nil
        return intent
    }

    mutating func rebuildHome() {
        path.removeAll()
        isShowingHelpTutorial = false
        isHomeReady = false
        isShowingNewFeatures = false
    }
}
