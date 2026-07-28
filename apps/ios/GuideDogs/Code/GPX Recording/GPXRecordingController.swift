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
    @Published var error: GPXRecordingError?
    @Published var proposedName = ""
    @Published private(set) var failedCloudSave = false

    private let draftStore: GPXRecordingDraftStore
    private let repository: GPXRecordingRepository
    private var locationTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(draftStore: GPXRecordingDraftStore = FileGPXRecordingDraftStore(),
         repository: GPXRecordingRepository = FileGPXRecordingRepository()) {
        self.draftStore = draftStore
        self.repository = repository

        let stateObserver = NotificationCenter.default.addObserver(
            forName: .appOperationStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let operationState = notification.userInfo?[AppContext.Keys.operationState] as? OperationState else {
                return
            }
            Task { @MainActor [weak self] in
                await self?.operationStateChanged(to: operationState)
            }
        }
        observers.append(stateObserver)

        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        observers.append(foregroundObserver)

        let stream = Self.locationStream()
        locationTask = Task { @MainActor [weak self] in
            for await point in stream {
                guard let self, !Task.isCancelled else {
                    return
                }
                await self.capture(point)
            }
        }

        Task { @MainActor [weak self] in
            await self?.load()
        }
    }

    deinit {
        locationTask?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func screenAppeared() {
        GDATelemetry.trackScreenView("gpx_recording")
        Task { await refresh() }
    }

    func start() {
        guard state == .idle else {
            return
        }
        error = nil
        failedCloudSave = false
        state = .starting
        let startedAt = Date()
        Task {
            do {
                try await draftStore.create(startedAt: startedAt)
                pointCount = 0
                state = AppContext.shared.state == .normal ? .recording : .paused
                GDATelemetry.track("gpx_recording.start")
                if state == .paused {
                    GDATelemetry.track("gpx_recording.pause")
                }
            } catch {
                self.error = .storage(error.localizedDescription)
                state = .idle
            }
        }
    }

    func stop() {
        guard state == .recording || state == .paused else {
            return
        }
        guard pointCount > 0 else {
            error = .noPoints
            return
        }
        proposedName = Self.defaultName()
        state = .awaitingName
        GDATelemetry.track("gpx_recording.stop")
    }

    func prepareRecoveredDraftForSaving() {
        guard state == .recoverableInterruption, pointCount > 0 else {
            return
        }
        proposedName = Self.defaultName()
        state = .awaitingName
    }

    func save(to forcedLocation: GPXRecordingStorageLocation? = nil) {
        guard state == .awaitingName || failedCloudSave else {
            return
        }
        let requestedName = proposedName
        state = .saving
        failedCloudSave = false
        error = nil

        Task {
            do {
                let name = try GPXRecordingNameValidator.normalizedName(requestedName)
                guard try await !repository.nameExists(name) else {
                    throw GPXRecordingError.duplicateName
                }
                guard let draft = try await draftStore.recover(), draft.pointCount > 0 else {
                    throw GPXRecordingError.noPoints
                }
                let destination: GPXRecordingStorageLocation
                if let forcedLocation {
                    destination = forcedLocation
                } else {
                    destination = await repository.preferredStorageLocation()
                }
                let file = try await repository.save(gpx: GPXRecordingDocumentBuilder.makeGPX(from: draft),
                                                     named: name,
                                                     to: destination)
                try await draftStore.discard()
                pointCount = 0
                state = .idle
                GDATelemetry.track("gpx_recording.save", with: ["destination": file.storageLocation.rawValue])
                await refresh()
            } catch let recordingError as GPXRecordingError {
                error = recordingError
                if case .iCloudSave = recordingError {
                    failedCloudSave = true
                }
                state = .awaitingName
            } catch {
                self.error = .storage(error.localizedDescription)
                state = .awaitingName
            }
        }
    }

    func retryCloudSave() {
        save(to: .iCloud)
    }

    func saveLocally() {
        save(to: .local)
    }

    func discard() {
        Task {
            do {
                try await draftStore.discard()
                pointCount = 0
                error = nil
                failedCloudSave = false
                state = .idle
                GDATelemetry.track("gpx_recording.discard")
            } catch {
                self.error = .storage(error.localizedDescription)
            }
        }
    }

    func refresh() async {
        do {
            recordings = try await repository.recordings()
        } catch {
            self.error = .storage(error.localizedDescription)
        }
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
            async let draft = draftStore.recover()
            async let files = repository.recordings()
            let (recoveredDraft, savedFiles) = try await (draft, files)
            recordings = savedFiles
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

    private func capture(_ point: GPXRecordingPoint) async {
        guard state == .recording else {
            return
        }
        do {
            try await draftStore.append(point)
            pointCount += 1
        } catch {
            self.error = .storage(error.localizedDescription)
        }
    }

    private func operationStateChanged(to operationState: OperationState) async {
        switch (state, operationState) {
        case (.recording, .sleep), (.recording, .snooze):
            state = .paused
            GDATelemetry.track("gpx_recording.pause")
        case (.paused, .normal):
            do {
                try await draftStore.beginSegment()
                state = .recording
                GDATelemetry.track("gpx_recording.resume")
            } catch {
                self.error = .storage(error.localizedDescription)
            }
        default:
            break
        }
    }

    private static func locationStream() -> AsyncStream<GPXRecordingPoint> {
        AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(
                forName: .locationUpdated,
                object: nil,
                queue: .main
            ) { notification in
                guard let location = notification.userInfo?[SpatialDataContext.Keys.location] as? CLLocation else {
                    return
                }
                let heading = AppContext.shared.geolocationManager.presentationHeading.value
                let activity = AppContext.shared.motionActivityContext.currentActivity.rawValue
                continuation.yield(GPXRecordingPoint(location: location,
                                                     heading: heading,
                                                     motionActivity: activity))
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
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
