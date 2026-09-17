//
//  SceneDelegate.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

protocol SceneIncomingEventHandling: AnyObject {
    func openURLResource(_ url: URL) -> Bool
    func handle(_ userActivity: NSUserActivity) -> Bool
}

extension AppDelegate: SceneIncomingEventHandling {}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var incomingEventHandler: SceneIncomingEventHandling?
    var notificationCenter: NotificationCenter = .default
    var validateActive: () -> Void = { AppContext.shared.validateActive() }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        routeIncomingEvents(urls: connectionOptions.urlContexts.map(\.url),
                            activities: Array(connectionOptions.userActivities))
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        routeIncomingEvents(urls: URLContexts.map(\.url), activities: [])
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        routeIncomingEvents(urls: [], activities: [userActivity])
    }

    func routeIncomingEvents(urls: [URL], activities: [NSUserActivity]) {
        guard let handler = incomingEventHandler ?? (UIApplication.shared.delegate as? SceneIncomingEventHandling) else { return }

        for url in urls {
            _ = handler.openURLResource(url)
        }

        for activity in activities {
            _ = handler.handle(activity)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        GDLogAppInfo("Application will resign active")
        AppContext.appState = .inactive
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        GDLogAppInfo("Application did enter background")
        AppContext.appState = .background
        notificationCenter.post(name: .appDidEnterBackground, object: nil)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        GDLogAppInfo("Application will enter foreground")
        AppContext.appState = .inactive
        notificationCenter.post(name: .appWillEnterForeground, object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        GDLogAppInfo("Application did become active")
        AppContext.appState = .active
        validateActive()
        notificationCenter.post(name: .appDidBecomeActive, object: nil)
    }
}
