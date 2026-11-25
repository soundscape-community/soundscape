// Copyright (c) Soundscape Community Contributors.
//
//  Integrations.swift
//  GuideDogs
//
//  Created by Daniel W. Steinbrook on 2/25/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

import UIKit

final class NaviLensWakeOnForeground {
    static let shared = NaviLensWakeOnForeground(notificationCenter: .default,
                                                 appState: { AppContext.shared.state },
                                                 sleep: { AppContext.shared.goToSleep() },
                                                 wake: { AppContext.shared.wakeUp() })

    private let notificationCenter: NotificationCenter
    private let appState: () -> OperationState
    private let sleep: () -> Void
    private let wake: () -> Void
    private var appDidBecomeActiveObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter,
         appState: @escaping () -> OperationState,
         sleep: @escaping () -> Void,
         wake: @escaping () -> Void) {
        self.notificationCenter = notificationCenter
        self.appState = appState
        self.sleep = sleep
        self.wake = wake
    }

    func sleepUntilForeground(autoSnoozeEnabled: Bool) -> Bool {
        assertMainThread()

        guard autoSnoozeEnabled, appState() == .normal else {
            return false
        }

        cancelPendingWake()

        appDidBecomeActiveObserver = notificationCenter.addObserver(forName: Notification.Name.appDidBecomeActive,
                                                                    object: nil,
                                                                    queue: .main) { [weak self] _ in
            self?.wakeUp()
        }

        sleep()
        return true
    }

    func wakeUp() {
        assertMainThread()

        guard cancelPendingWake() else {
            return
        }

        wake()
    }

    @discardableResult
    private func cancelPendingWake() -> Bool {
        assertMainThread()

        guard let observer = appDidBecomeActiveObserver else {
            return false
        }

        notificationCenter.removeObserver(observer)
        appDidBecomeActiveObserver = nil
        return true
    }

    private func assertMainThread() {
        assert(Thread.isMainThread, "NaviLensWakeOnForeground must be used on the main thread")
    }
}

/// Injectable system boundaries keep launch reporting and failed-open recovery testable.
struct NaviLensLauncher {
    let canOpen: (URL) -> Bool
    let open: (URL, @escaping (Bool) -> Void) -> Void
    let sleepUntilForeground: () -> Bool
    let wake: () -> Void
    let report: (String, Bool) -> Void

    func launch() {
        let didScheduleWake = sleepUntilForeground()
        let navilensURL = URL(string: "navilens://")!
        let appStoreURL = URL(string: "https://apps.apple.com/us/app/navilens/id1273704914")!
        let installed = canOpen(navilensURL)
        open(installed ? navilensURL : appStoreURL) { success in
            report(installed ? "navilens" : "app_store", success)
            if !success && didScheduleWake { wake() }
        }
    }
}

func launchNaviLensApp() {
    let occurrence = GDATelemetry.captureOccurrence()
    let wakeOnForeground = NaviLensWakeOnForeground.shared
    NaviLensLauncher(canOpen: { UIApplication.shared.canOpenURL($0) },
                     open: { UIApplication.shared.open($0, completionHandler: $1) },
                     sleepUntilForeground: {
                         wakeOnForeground.sleepUntilForeground(autoSnoozeEnabled: SettingsContext.shared.naviLensAutoSnoozeEnabled)
                     },
                     wake: { wakeOnForeground.wakeUp() },
                     report: { destination, success in
                         guard let occurrence = occurrence else { return }
                         GDATelemetry.track("navilens.launch", with: ["destination": destination,
                                                                    "success": String(success)], occurrence: occurrence)
                     }).launch()
}

func launchNaviLens(detail: LocationDetail) {
    launchNaviLensApp()
}
