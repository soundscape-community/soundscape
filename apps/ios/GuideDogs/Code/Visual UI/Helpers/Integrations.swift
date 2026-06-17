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

    func sleepUntilForeground() -> Bool {
        assertMainThread()

        guard appState() == .normal else {
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

func launchNaviLensApp() {
    let wakeOnForeground = NaviLensWakeOnForeground.shared
    let didScheduleWake = wakeOnForeground.sleepUntilForeground()

    // Launch NaviLens app, or open App Store listing if not installed
    let navilensUrl = URL(string: "navilens://")!
    let appStoreUrl = URL(string: "https://apps.apple.com/us/app/navilens/id1273704914")!
    let url = UIApplication.shared.canOpenURL(navilensUrl) ? navilensUrl : appStoreUrl

    UIApplication.shared.open(url) { success in
        guard !success else {
            return
        }

        if didScheduleWake {
            wakeOnForeground.wakeUp()
        }
    }
}

func launchNaviLens(detail: LocationDetail) {
    launchNaviLensApp()
}
