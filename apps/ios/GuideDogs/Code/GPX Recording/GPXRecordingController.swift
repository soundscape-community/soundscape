//
//  GPXRecordingController.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import UIKit

@MainActor
final class GPXRecordingController: ObservableObject {
    static let shared = GPXRecordingController()

    @Published private(set) var state: GPXRecordingState = .loading
    @Published private(set) var recordings: [GPXRecordingFile] = []
    @Published private(set) var pointCount = 0
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshError: GPXRecordingError?
    @Published var error: GPXRecordingError?
    @Published var proposedName = ""

    private let draftStore: GPXRecordingDraftStore
    private let repository: GPXRecordingRepository
    private var refreshRequest = 0
    private var refreshTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var operationRequest = 0
    private var session = UUID()
    private var transitionRevision = 0
    private var operationState: OperationState
    private var discardReturnState: GPXRecordingState?
    private var observers: [NSObjectProtocol] = []

    init(draftStore: GPXRecordingDraftStore = FileGPXRecordingDraftStore(),
         repository: GPXRecordingRepository = FileGPXRecordingRepository(),
         initialOperationState: OperationState = AppContext.shared.state,
         observeEvents: Bool = true) {
        self.draftStore = draftStore
        self.repository = repository
        operationState = initialOperationState

        enqueue { controller, _ in await controller.load() }
        requestRefresh()
        guard observeEvents else { return }

        // NotificationCenter delivers these callbacks on the main queue. Admit events
        // synchronously there so a later Stop cannot overtake an accepted point.
        let stateObserver = NotificationCenter.default.addObserver(
            forName: .appOperationStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let operationState = notification.userInfo?[AppContext.Keys.operationState] as? OperationState else {
                return
            }
            MainActor.assumeIsolated {
                self?.operationStateChanged(to: operationState)
            }
        }
        observers.append(stateObserver)

        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.requestRefresh()
            }
        }
        observers.append(foregroundObserver)

        let locationObserver = NotificationCenter.default.addObserver(
            forName: .locationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let location = notification.userInfo?[SpatialDataContext.Keys.location] as? CLLocation else {
                return
            }
            MainActor.assumeIsolated {
                let heading = AppContext.shared.geolocationManager.presentationHeading.value
                let activity = AppContext.shared.motionActivityContext.currentActivity.rawValue
                self?.capture(GPXRecordingPoint(location: location, heading: heading, motionActivity: activity))
            }
        }
        observers.append(locationObserver)
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func screenAppeared() {
        GDATelemetry.trackScreenView("gpx_recording")
        requestRefresh()
    }

    var isNamingPresented: Bool {
        state == .awaitingName || state == .saving
            || (state == .discarding && discardReturnState == .awaitingName)
    }

    // A finite chain owns accepted work independently of screen lifetime. Each task
    // waits for its predecessor, including all of that operation's suspension points.
    private func enqueue(_ operation: @escaping @MainActor (GPXRecordingController, UUID) async -> Void) {
        let previous = operationTask
        let acceptedSession = session
        operationRequest += 1
        let request = operationRequest
        operationTask = Task {
            await previous?.value
            if acceptedSession == session {
                await operation(self, acceptedSession)
            }
            if request == operationRequest { operationTask = nil }
        }
    }

    func waitForPendingOperations() async {
        while let operationTask { await operationTask.value }
    }

    func start() {
        guard state == .idle else {
            return
        }
        error = nil
        session = UUID()
        transitionRevision += 1
        state = .starting
        let startedAt = Date()
        enqueue { controller, session in
            do {
                try await controller.draftStore.create(startedAt: startedAt)
                guard controller.session == session else { return }
                controller.pointCount = 0
                controller.state = controller.operationState == .normal ? .recording : .paused
                GDATelemetry.track("gpx_recording.start")
                if controller.state == .paused {
                    GDATelemetry.track("gpx_recording.pause")
                }
            } catch {
                guard controller.session == session else { return }
                controller.error = .storage(error.localizedDescription)
                controller.state = .idle
            }
        }
    }

    func stop() {
        guard state == .recording || state == .paused else {
            return
        }
        transitionRevision += 1
        state = .stopping
        enqueue { controller, session in
            if controller.pointCount == 0 {
                do {
                    try await controller.draftStore.discard()
                    guard controller.session == session else { return }
                    controller.state = .idle
                    GDATelemetry.track("gpx_recording.discard")
                } catch {
                    guard controller.session == session else { return }
                    controller.error = .storage(error.localizedDescription)
                    controller.state = .recoverableInterruption
                }
            } else {
                controller.proposedName = Self.defaultName()
                controller.state = .awaitingName
                GDATelemetry.track("gpx_recording.stop")
            }
        }
    }

    func prepareRecoveredDraftForSaving() {
        guard state == .recoverableInterruption, pointCount > 0 else {
            return
        }
        proposedName = Self.defaultName()
        state = .awaitingName
    }

    func save() {
        guard state == .awaitingName else {
            return
        }
        let requestedName = proposedName
        state = .saving
        error = nil

        enqueue { controller, session in
            do {
                let name = try GPXRecordingNameValidator.normalizedName(requestedName)
                guard let draft = try await controller.draftStore.recover(), draft.pointCount > 0 else {
                    throw GPXRecordingError.noPoints
                }
                let file = try await controller.repository.save(draft: draft, named: name)
                guard controller.session == session else { return }
                // Invalidate every listing begun before this commit, then publish it
                // immediately. Reconciliation has a separate lifetime and error channel.
                controller.refreshRequest += 1
                controller.refreshTask = nil
                controller.isRefreshing = false
                controller.refreshError = nil
                controller.recordings = (controller.recordings.filter { $0.id != file.id } + [file])
                    .sorted(by: GPXRecordingFile.newestFirst)
                do {
                    try await controller.draftStore.discard()
                } catch {
                    controller.error = .storage(error.localizedDescription)
                }
                guard controller.session == session else { return }
                controller.pointCount = 0
                GDATelemetry.track("gpx_recording.save", with: ["destination": "local"])
                controller.state = .idle
                controller.requestRefresh()
            } catch let recordingError as GPXRecordingError {
                guard controller.session == session else { return }
                controller.error = recordingError
                controller.state = .awaitingName
            } catch {
                guard controller.session == session else { return }
                controller.error = .storage(error.localizedDescription)
                controller.state = .awaitingName
            }
        }
    }

    func discard() {
        guard state == .awaitingName || state == .recoverableInterruption else { return }
        let previousState = state
        discardReturnState = previousState
        transitionRevision += 1
        state = .discarding
        error = nil
        enqueue { controller, session in
            do {
                try await controller.draftStore.discard()
                guard controller.session == session else { return }
                controller.pointCount = 0
                controller.state = .idle
                GDATelemetry.track("gpx_recording.discard")
            } catch {
                guard controller.session == session else { return }
                controller.error = .storage(error.localizedDescription)
                controller.state = previousState
            }
            controller.discardReturnState = nil
        }
    }

    func refresh() async {
        await requestRefresh().value
    }

    func waitForPendingRefresh() async {
        while let refreshTask { await refreshTask.value }
    }

    @discardableResult
    private func requestRefresh() -> Task<Void, Never> {
        refreshRequest += 1
        let request = refreshRequest
        isRefreshing = true
        refreshError = nil
        let task = Task {
            do {
                let files = try await repository.recordings()
                guard request == refreshRequest else { return }
                recordings = files
            } catch {
                guard request == refreshRequest else { return }
                refreshError = .storage(error.localizedDescription)
            }
            isRefreshing = false
            refreshTask = nil
        }
        refreshTask = task
        return task
    }

    func share(_ file: GPXRecordingFile) {
        Task {
            do {
                let url = try await repository.prepareForSharing(file)
                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                guard let viewController = Self.topViewController(from: AppContext.rootViewController) else {
                    throw GPXRecordingError.storage(GDLocalizedString("gpx_recording.error.share_unavailable"))
                }
                activity.popoverPresentationController?.sourceView = viewController.view
                activity.completionWithItemsHandler = { _, completed, _, _ in
                    GDATelemetry.track("gpx_recording.share", with: ["outcome": completed ? "completed" : "cancelled"])
                }
                viewController.present(activity, animated: true)
            } catch {
                self.error = .storage(error.localizedDescription)
                GDATelemetry.track("gpx_recording.share", with: ["outcome": "failed"])
            }
        }
    }

    private func load() async {
        do {
            let recoveredDraft = try await draftStore.recover()
            pointCount = recoveredDraft?.pointCount ?? 0
            if let recoveredDraft {
                if recoveredDraft.pointCount > 0 {
                    state = .recoverableInterruption
                } else {
                    try await draftStore.discard()
                    state = .idle
                }
            } else {
                state = .idle
            }
        } catch {
            self.error = .storage(error.localizedDescription)
            state = .idle
        }
    }

    func capture(_ point: GPXRecordingPoint) {
        guard state == .recording else {
            return
        }
        enqueue { controller, session in
            do {
                try await controller.draftStore.append(point)
                guard controller.session == session else { return }
                controller.pointCount += 1
            } catch {
                guard controller.session == session else { return }
                controller.error = .storage(error.localizedDescription)
            }
        }
    }

    func operationStateChanged(to operationState: OperationState) {
        guard operationState != self.operationState else { return }
        self.operationState = operationState
        transitionRevision += 1
        let revision = transitionRevision
        switch (state, operationState) {
        case (.recording, .sleep), (.recording, .snooze):
            state = .paused
            GDATelemetry.track("gpx_recording.pause")
        case (.paused, .normal):
            enqueue { controller, session in
                guard controller.transitionRevision == revision else { return }
                do {
                    try await controller.draftStore.beginSegment()
                    guard controller.session == session, controller.transitionRevision == revision else { return }
                    controller.state = .recording
                    GDATelemetry.track("gpx_recording.resume")
                } catch {
                    guard controller.session == session, controller.transitionRevision == revision else { return }
                    controller.error = .storage(error.localizedDescription)
                }
            }
        default:
            break
        }
    }

    private static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter.string(from: Date())
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigationController = root as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = root as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        return root
    }
}
