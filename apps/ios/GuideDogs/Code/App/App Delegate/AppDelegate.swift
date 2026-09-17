//
//  AppDelegate.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import CocoaLumberjackSwift

// Uncomment for Siri use:
// import Intents.NSUserActivity_IntentsAdditions

extension Notification.Name {
    static let appWillEnterForeground = Notification.Name("GDAAppWillEnterForeground")
    static let appDidBecomeActive = Notification.Name("GDAAppDidBecomeActive")
    static let appDidEnterBackground = Notification.Name("GDAAppDidEnterBackground")
    static let didRegisterForRemoteNotifications = Notification.Name("GDADidRegisterForRemoteNotifications")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: Properties

    private let userActivityManager = UserActivityManager()
    private let urlResourceManager = URLResourceManager()
    let pushNotificationManager = PushNotificationManager(userId: SettingsContext.shared.clientId)
    
    // MARK: UIApplicationDelegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Check if we need to migrate Realm before we do anything else
        RealmMigrationTools.migrate(database: RealmHelper.databaseConfig, cache: RealmHelper.cacheConfig)

        do {
            try InternalStorage.migrateLegacyStorageIfNeeded()
        } catch {
            // Internal storage is non-critical. Continue launching and retry the
            // idempotent migration on the next launch.
            GDLogAppError("Unable to migrate legacy internal storage: \(error.localizedDescription)")
        }
        
        if FirstUseExperience.didComplete(.oobe) {
            // Only increment app use count if the user has completed onboarding
            SettingsContext.shared.appUseCount += 1
        }
        
        // Note: Remainder of app initialization is handled in DynamicLaunchViewController.swift and LaunchHelper.swift...
        // DO NOT reference `AppContext.shared` until the notification `Notification.Name.appDidInitialize` is posted
        
        if let launchOptions = launchOptions {
            pushNotificationManager.didFinishLaunchingWithOptions(launchOptions)
        }

        return true
    }

    func handle(_ userActivity: NSUserActivity) -> Bool {
        return userActivityManager.onContinueUserActivity(userActivity)
    }

    func openURLResource(_ url: URL) -> Bool {
        GDLogAppInfo("Application asked to open file: \(url.lastPathComponent)")

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true){
           if let source = components.queryItems?.first(where: { $0.name == "source" })?.value {
            GDLogAppInfo("App opened from source: \(source)")
            GDATelemetry.track("app.open", with: ["source": source])
           }
        } else {
            GDLogAppError("Handling incoming shared URL failed - unable to parse URL components")
        }
        return urlResourceManager.onOpenResource(from: url)
    }
    
    // MARK: Application life cycle

    /// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    func applicationWillTerminate(_ application: UIApplication) {
        GDLogAppInfo("Application will terminate")
        
        if AppContext.shared.geolocationManager.isTracking {
            AppContext.shared.geolocationManager.stopTrackingGPX()
        }
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        GDLogAppInfo("Application did receive memory warning")
        
        if let memoryAllocated = AppContext.memoryAllocated {
            GDLogAppInfo("Memory used: " + ByteCountFormatter.string(fromByteCount: Int64(memoryAllocated), countStyle: .memory))
        }
    }
    
}

// MARK: Push Notifications

extension AppDelegate {
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        GDLogPushInfo("Did register for remote notifications")
        
        NotificationCenter.default.post(name: Notification.Name.didRegisterForRemoteNotifications, object: self)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        GDLogPushInfo("Did fail to register for remote notifications with error: \(error)")
    }
    
}
