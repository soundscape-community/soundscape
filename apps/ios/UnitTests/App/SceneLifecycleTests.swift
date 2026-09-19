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

    func testIncomingRouteIsCopiedBeforeQueuedImportAndPreservesOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let importDirectory = root.appendingPathComponent("Staged", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = URLResourceManager(importDirectory: importDirectory)
        let coldSource = root.appendingPathComponent("cold.soundscape")
        let warmSource = root.appendingPathComponent("warm.soundscape")
        try makeRouteFile(at: coldSource, name: "Cold import")
        try makeRouteFile(at: warmSource, name: "Warm import")

        let coldImported = expectation(description: "Cold route imported after its source disappeared")
        let warmImported = expectation(description: "Warm route imported from its staged copy")
        let observer = NotificationCenter.default.addObserver(forName: .didImportRoute, object: nil, queue: .main) { notification in
            guard let route = notification.userInfo?[RouteResourceHandler.Keys.route] as? Route else { return }
            switch route.name {
            case "Cold import": coldImported.fulfill()
            case "Warm import": warmImported.fulfill()
            default: break
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        XCTAssertTrue(manager.onOpenResource(from: coldSource))
        try FileManager.default.removeItem(at: coldSource)
        NotificationCenter.default.post(name: .homeViewControllerDidLoad, object: nil)
        wait(for: [coldImported], timeout: 5)

        XCTAssertTrue(manager.onOpenResource(from: warmSource))
        XCTAssertTrue(FileManager.default.fileExists(atPath: warmSource.path))
        try FileManager.default.removeItem(at: warmSource)
        wait(for: [warmImported], timeout: 5)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: importDirectory.path), [])
    }

    func testInvalidIncomingFilesArePreservedAndStagingIsCleaned() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let staging = root.appendingPathComponent("Staged", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = URLResourceManager(importDirectory: staging)
        let directory = root.appendingPathComponent("directory.soundscape", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oversized = root.appendingPathComponent("oversized.soundscape")
        XCTAssertTrue(FileManager.default.createFile(atPath: oversized.path, contents: nil))
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: 50 * 1024 * 1024 + 1)
        try handle.close()
        let malformed = root.appendingPathComponent("malformed.soundscape")
        try Data("not JSON".utf8).write(to: malformed)

        let failed = expectation(description: "Invalid files report import failure")
        failed.expectedFulfillmentCount = 3
        let observer = NotificationCenter.default.addObserver(forName: .didFailToImportRoute, object: nil, queue: .main) { _ in
            failed.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        for source in [directory, oversized] {
            XCTAssertTrue(manager.onOpenResource(from: source))
            // Rejected during staging, before the home screen is ready.
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
        }
        XCTAssertTrue(manager.onOpenResource(from: malformed))
        NotificationCenter.default.post(name: .homeViewControllerDidLoad, object: nil)
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
        for source in [directory, oversized, malformed] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        }
    }

    func testOnlyExpiredImportDirectoriesAreRemovedAtStartup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let expired = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let recent = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let unrelated = root.appendingPathComponent("Unrelated", isDirectory: true)
        let oldDate = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        for directory in [expired, recent, unrelated] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("staged".utf8).write(to: directory.appendingPathComponent("route.soundscape"))
        }
        for directory in [expired, unrelated] {
            try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: directory.path)
        }
        let manager = URLResourceManager(importDirectory: root)
        withExtendedLifetime(manager) {
            XCTAssertFalse(FileManager.default.fileExists(atPath: expired.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        }
    }

    func testMissingIncomingFileReportsImportFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = URLResourceManager(importDirectory: root.appendingPathComponent("Staged", isDirectory: true))
        let routeFailed = expectation(description: "Missing route reports import failure")
        let gpxFailed = expectation(description: "Missing GPX reports import failure")
        let routeObserver = NotificationCenter.default.addObserver(forName: .didFailToImportRoute, object: nil, queue: .main) { _ in
            routeFailed.fulfill()
        }
        let gpxObserver = NotificationCenter.default.addObserver(forName: .didImportGPXResource, object: nil, queue: .main) { notification in
            XCTAssertEqual(notification.userInfo?[GPXResourceHandler.Keys.filename] as? String, "missing.gpx")
            XCTAssertNotNil(notification.userInfo?[GPXResourceHandler.Keys.error] as? Error)
            gpxFailed.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(routeObserver)
            NotificationCenter.default.removeObserver(gpxObserver)
        }

        XCTAssertTrue(manager.onOpenResource(from: root.appendingPathComponent("missing.soundscape")))
        XCTAssertTrue(manager.onOpenResource(from: root.appendingPathComponent("missing.gpx")))
        NotificationCenter.default.post(name: .homeViewControllerDidLoad, object: nil)
        wait(for: [routeFailed, gpxFailed], timeout: 5)
    }

    func testRouteDocumentWithUnsupportedEntitySourceUsesWaypointCoordinates() throws {
        let document = """
        {
          "id": "route-id",
          "name": "Shared route",
          "waypoints": [{
            "index": 0,
            "markerId": "marker-id",
            "marker": {
              "nickname": "Stop",
              "location": {
                "name": "Waypoint",
                "coordinate": {"latitude": 55.9, "longitude": -3.1},
                "entity": {"source": 1, "lookupInformation": "old-provider-id"}
              }
            }
          }]
        }
        """

        let route = try XCTUnwrap(RouteParameters.decode(Data(document.utf8)))
        let marker = try XCTUnwrap(route.waypoints.first?.marker)
        XCTAssertEqual(marker.location.name, "Waypoint")
        XCTAssertEqual(marker.location.coordinate.latitude, 55.9)
        XCTAssertEqual(marker.location.coordinate.longitude, -3.1)
        XCTAssertNil(marker.location.entity)
        XCTAssertEqual(marker.nickname, "Stop")

        let supportedDocument = document.replacingOccurrences(of: "\"source\": 1", with: "\"source\": 0")
        let supportedRoute = try XCTUnwrap(RouteParameters.decode(Data(supportedDocument.utf8)))
        XCTAssertEqual(supportedRoute.waypoints.first?.marker?.location.entity?.source, .osm)
    }

    private func makeRouteFile(at url: URL, name: String) throws {
        let parameters = RouteParameters(id: UUID().uuidString,
                                         name: name,
                                         routeDescription: nil,
                                         waypoints: [],
                                         createdDate: nil,
                                         lastUpdatedDate: nil,
                                         lastSelectedDate: nil)
        try XCTUnwrap(RouteParameters.encode(parameters)).write(to: url)
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
