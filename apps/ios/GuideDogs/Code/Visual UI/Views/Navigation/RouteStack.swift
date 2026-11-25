// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI

struct RouteStack<Route: Hashable, Root: View, Destination: View>: View {
    @Binding var path: [Route]
    @ViewBuilder var root: () -> Root
    @ViewBuilder var destination: (Route) -> Destination

    var body: some View {
        NavigationStack(path: $path) {
            root().navigationDestination(for: Route.self, destination: destination)
        }
    }
}

final class AppNavigationModel: ObservableObject {
    static let shared = AppNavigationModel()

    @Published private(set) var coordinator = AppCoordinator()
    private(set) var editors: [String: ViewControllerRepresentable] = [:]
    private(set) var locations: [String: LocationDetail] = [:]
    private var locationActions: [String: LocationAction] = [:]
    var shouldFocusOnBeacon = false
    private(set) var isStandbyActive = false
    private var intentAfterStandby: (() -> Void)?

    func update(_ change: (inout AppCoordinator) -> Void) {
        var state = coordinator
        change(&state)
        coordinator = state
        let locationIDs = Set(state.path.compactMap { route -> String? in
            if case .location(let id) = route { return id }
            return nil
        })
        let editorIDs = Set(state.path.compactMap { route -> String? in
            if case .editor(let id) = route { return id }
            return nil
        })
        editors = editors.filter { editorIDs.contains($0.key) }
        locations = locations.filter { locationIDs.contains($0.key) }
        locationActions = locationActions.filter { locationIDs.contains($0.key) }
    }

    func open(_ route: AppRoute) {
        update { $0.open(route) }
    }

    func showLocation(_ detail: LocationDetail, action: LocationAction? = nil) {
        guard coordinator.stage == .home else { return }
        let id: String
        switch detail.source {
        case .entity(let key): id = "entity/" + key
        case .coordinate(let location):
            id = "coordinate/\(location.coordinate.latitude)/\(location.coordinate.longitude)"
        case .designData, .screenshots: id = UUID().uuidString
        }
        locations[id] = detail
        locationActions[id] = action
        open(.location(id))
    }

    func takeAction(forLocation id: String) -> LocationAction? {
        locationActions.removeValue(forKey: id)
    }

    func openNotificationDestination(_ destination: ViewControllerRepresentable) {
        guard coordinator.stage == .home else { return }
        if let known = destination as? AnyViewControllerRepresentable {
            switch known.destination {
            case .offlineHelp: open(.helpPage(.offline))
            case .routeGuidance: open(.activeRoute)
            case .manageDevices: open(.devices)
            }
        } else {
            openEditor(destination)
        }
    }

    func openEditor(_ editor: ViewControllerRepresentable) {
        guard coordinator.stage == .home else { return }
        let id = UUID().uuidString
        editors[id] = editor
        open(.editor(id))
    }

    func close(_ route: AppRoute) {
        update { $0.close(route) }
    }

    func returnHome(focusOnBeacon: Bool = false) {
        shouldFocusOnBeacon = focusOnBeacon
        update { $0.updatePath([]) }
    }

    var path: Binding<[AppRoute]> {
        Binding(get: { self.coordinator.path }, set: { path in self.update { $0.updatePath(path) } })
    }

    var newFeatures: Binding<Bool> {
        Binding(get: { self.coordinator.isShowingNewFeatures }, set: { presented in
            self.update { $0.setNewFeaturesPresented(presented) }
        })
    }

    var helpTutorial: Binding<Bool> {
        Binding(get: { self.coordinator.isShowingHelpTutorial }, set: { presented in
            self.update { $0.setHelpTutorialPresented(presented) }
        })
    }

    var standby: Binding<Bool> {
        Binding(get: { self.coordinator.isShowingStandby }, set: { presented in
            self.update { $0.setStandbyPresented(presented) }
        })
    }

    func showStandby() {
        standby.wrappedValue = true
        isStandbyActive = coordinator.isShowingStandby
    }

    func afterStandby(_ action: @escaping () -> Void) {
        intentAfterStandby = action
        // If the cover is still appearing, standbyDidAppear will wake the app once it goes to sleep.
        if AppContext.shared.state != .normal {
            AppContext.shared.wakeUp()
            standby.wrappedValue = false
        }
    }

    func standbyDidAppear() {
        AppContext.shared.goToSleep()
        if intentAfterStandby != nil {
            AppContext.shared.wakeUp()
            standby.wrappedValue = false
        }
    }

    func standbyDidDismiss() {
        isStandbyActive = false
        if AppContext.shared.eventProcessor.activeBehavior is RouteGuidance,
           !AppContext.shared.spatialDataContext.destinationManager.isAudioEnabled {
            AppContext.shared.spatialDataContext.destinationManager.toggleDestinationAudio()
        }
        let action = intentAfterStandby
        intentAfterStandby = nil
        action?()
    }

    func receive(_ intent: AppNavigationIntent) -> AppNavigationIntent? {
        var state = coordinator
        let ready = state.receive(intent)
        if ready == nil { coordinator = state }
        return ready
    }

    func homeBecameReady() -> AppNavigationIntent? {
        var state = coordinator
        let intents = state.homeBecameReady()
        coordinator = state
        return intents
    }
}
