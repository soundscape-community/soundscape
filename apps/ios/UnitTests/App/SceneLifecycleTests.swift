//
//  SceneLifecycleTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import XCTest
@testable import Soundscape

final class SceneLifecycleTests: XCTestCase {

    @MainActor
    func testSceneConfigurationCreatesTheAppWindow() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        let manifest = try XCTUnwrap(info["UIApplicationSceneManifest"] as? [String: Any])
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let applicationScenes = try XCTUnwrap(configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]])
        let configuration = try XCTUnwrap(applicationScenes.first)

        XCTAssertEqual(applicationScenes.count, 1)
        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, false)
        XCTAssertEqual(configuration["UISceneDelegateClassName"] as? String, NSStringFromClass(SceneDelegate.self))
        XCTAssertEqual(configuration["UISceneStoryboardFile"] as? String, "Launch-Dynamic")
        XCTAssertNil(info["UIMainStoryboardFile"])
        XCTAssertEqual(info["UILaunchStoryboardName"] as? String, "Launch-Static")

        let window = try XCTUnwrap(AppContext.window)
        XCTAssertTrue(window.windowScene?.delegate is SceneDelegate)
        XCTAssertNotNil(window.rootViewController)
        XCTAssertTrue(AppContext.rootViewController === window.rootViewController)
    }

    @MainActor
    func testSceneLifecycleUpdatesStateAndPostsAppNotifications() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
        let delegate = SceneDelegate()
        let notificationCenter = NotificationCenter()
        delegate.notificationCenter = notificationCenter
        var validationCount = 0
        delegate.validateActive = { validationCount += 1 }
        let previousState = AppContext.appState
        let names: [Notification.Name] = [.appDidEnterBackground, .appWillEnterForeground, .appDidBecomeActive]
        var received: [Notification.Name] = []
        let observers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: nil) { notification in
                received.append(notification.name)
            }
        }
        defer {
            observers.forEach(notificationCenter.removeObserver)
            AppContext.appState = previousState
        }

        delegate.sceneWillResignActive(scene)
        XCTAssertEqual(AppContext.appState, .inactive)

        delegate.sceneDidEnterBackground(scene)
        XCTAssertEqual(AppContext.appState, .background)

        delegate.sceneWillEnterForeground(scene)
        XCTAssertEqual(AppContext.appState, .inactive)

        delegate.sceneDidBecomeActive(scene)
        XCTAssertEqual(AppContext.appState, .active)
        XCTAssertEqual(validationCount, 1)
        XCTAssertEqual(received, names)
    }

    @MainActor
    func testIncomingEventsAreForwardedOnce() {
        let delegate = SceneDelegate()
        let handler = IncomingEventSpy()
        delegate.incomingEventHandler = handler

        let coldURL = URL(fileURLWithPath: "/tmp/cold.gpx")
        let warmURL = URL(fileURLWithPath: "/tmp/warm.soundscape")
        let coldActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        let warmActivity = NSUserActivity(activityType: "services.soundscape.activity.search")
        let notificationPayload: PushNotification.Payload = ["aps": ["alert": "Open Soundscape"]]

        delegate.routeIncomingEvents(urls: [coldURL], activities: [coldActivity], notificationPayload: notificationPayload)
        delegate.routeIncomingEvents(urls: [warmURL], activities: [warmActivity])

        XCTAssertEqual(handler.urls, [coldURL, warmURL])
        XCTAssertEqual(handler.activities.count, 2)
        XCTAssertTrue(handler.activities[0] === coldActivity)
        XCTAssertTrue(handler.activities[1] === warmActivity)
        XCTAssertEqual(handler.notificationPayloads.count, 1)
        XCTAssertEqual(handler.notificationPayloads[0]["aps"] as? [String: String], ["alert": "Open Soundscape"])
    }
}

private final class IncomingEventSpy: SceneIncomingEventHandling {
    var urls: [URL] = []
    var activities: [NSUserActivity] = []
    var notificationPayloads: [PushNotification.Payload] = []

    func openURLResource(_ url: URL) -> Bool {
        urls.append(url)
        return true
    }

    func handle(_ userActivity: NSUserActivity) -> Bool {
        activities.append(userActivity)
        return true
    }

    func handleLaunchNotification(payload: PushNotification.Payload) {
        notificationPayloads.append(payload)
    }
}
