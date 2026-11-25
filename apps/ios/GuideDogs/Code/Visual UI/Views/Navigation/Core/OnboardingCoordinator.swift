// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

enum OnboardingRoute: String, Hashable {
    case language, headphones, callouts, authorizations, beacon, terms, finish
}

struct OnboardingCoordinator {
    private(set) var path: [OnboardingRoute] = []
    let needsTerms: Bool

    func firstRoute(languageMatches: Bool) -> OnboardingRoute {
        languageMatches ? .headphones : .language
    }

    func routeAfterAuthorizations(allGranted: Bool) -> OnboardingRoute {
        allGranted ? .beacon : routeAfterBeacon
    }

    var routeAfterBeacon: OnboardingRoute {
        needsTerms ? .terms : .finish
    }

    mutating func open(_ route: OnboardingRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    mutating func updatePath(_ path: [OnboardingRoute]) {
        self.path = path
    }
}
