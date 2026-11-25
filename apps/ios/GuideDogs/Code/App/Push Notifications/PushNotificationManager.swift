//
//  PushNotificationManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import Combine

extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("GDAPushNotificationReceived")
}

/// A class to handle actions related to remote push notifications
class PushNotificationManager: NSObject {
    
    // MARK: Constants
    
    struct NotificationKeys {
        static let pushNotification = "GDAPushNotification"
    }

    private static var globalTags: [String: String] {
        let tags = [
            "device.model": UIDevice.current.modelName,
            "device.os.version": UIDevice.current.systemVersion,
            "device.voice_over": UIAccessibility.isVoiceOverRunning ? "on" : "off",
            
            "app.version": AppContext.appVersion,
            "app.build": AppContext.appBuild,
            "app.source": BuildSettings.source.rawValue,
            
            "app.language": LocalizationContext.currentLanguageCode,
            "app.region": LocalizationContext.currentRegionCode
        ].mapValues { $0.lowercased().replace(characterSet: .whitespacesAndNewlines, with: "-") }
        
        return tags
    }
    
    // MARK: - Properties
    
    private var userId: String?
    private var subscribers: [AnyCancellable] = []
    
    private var onboardingDidComplete = false
    private var appDidInitialize = false
    private var pendingPushNotification: PushNotification?
    
    private(set) var localPushNotificationManager = LocalPushNotificationManager()
    
    private var handledDeliveries: [String] = []
    
    // MARK: - Initialization
    
    init(userId: String? = nil) {
        super.init()
        
        UNUserNotificationCenter.current().delegate = self

        self.userId = userId
        self.onboardingDidComplete = FirstUseExperience.didComplete(.oobe)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onAppDidInitialize),
                                               name: NSNotification.Name.appDidInitialize,
                                               object: nil)
        
        if onboardingDidComplete == false {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(onOnboardingDidComplete),
                                                   name: .onboardingDidComplete,
                                                   object: nil)
        }
        
        subscribers.append(NotificationCenter.default
                            .publisher(for: .didRegisterForRemoteNotifications)
                            .receive(on: RunLoop.main)
                            .sink { [weak self] _ in
            guard let `self` = self else {
                return
            }
            
            if let userId = self.userId {
                self.updateUserIdIfNeeded(userId: userId)
            }
            
            self.updateTagsIfNeeded()
        })
    }
    
    deinit {
        subscribers.forEach({ $0.cancel() })
        subscribers.removeAll()
    }
    
    // MARK: Class Methods
    
    /// Initializes the Azure Notification Hub
    func start() {
        guard onboardingDidComplete else {
            // Do not start until the OOBE completes
            // Once the notification hub is started, the user will be asked
            // to approve notification permissions
            return
        }
    }
    
    private func updateUserIdIfNeeded(userId: String) {
        //XXX removed Azure-specific implementation
    }
    
    private func updateTagsIfNeeded() {
        //XXX removed Azure-specific implementation
    }
    
    static func deliveryID(for notification: UNNotification) -> String {
        notification.request.identifier + "/" + String(notification.date.timeIntervalSinceReferenceDate)
    }

    func receive(payload: PushNotification.Payload, deliveryID: String?, arrival: PushNotification.ArrivalContext) {
        if let deliveryID {
            guard !handledDeliveries.contains(deliveryID) else { return }
            handledDeliveries.append(deliveryID)
            if handledDeliveries.count > 32 {
                handledDeliveries.removeFirst()
            }
        }

        didReceive(pushNotification: PushNotification(payload: payload, arrivalContext: arrival))
    }

    // MARK: Receiving Push Notifications
    
    private func didReceive(pushNotification: PushNotification) {
        guard appDidInitialize else {
            pendingPushNotification = pushNotification
            GDLogPushInfo("Did receive pending push notification")
            return
        }
        
        GDLogPushInfo(String(format: "Did receive push notification. App state: %@, Origin context: %@, Arrival context: %@, Payload: %@",
                      UIApplication.shared.applicationState.description,
                      pushNotification.originContext.rawValue,
                      pushNotification.arrivalContext.rawValue,
                      pushNotification.payload))

        NotificationCenter.default.post(name: Notification.Name.pushNotificationReceived,
                                        object: nil,
                                        userInfo: [NotificationKeys.pushNotification: pushNotification])
    }
    
    // MARK: Notifications
    
    @objc private func onOnboardingDidComplete() {
        onboardingDidComplete = true
        NotificationCenter.default.removeObserver(self, name: .onboardingDidComplete, object: nil)
        
        start()
        
        if appDidInitialize, let pendingPushNotification = pendingPushNotification {
            didReceive(pushNotification: pendingPushNotification)
            self.pendingPushNotification = nil
        }
    }
    
    @objc private func onAppDidInitialize() {
        appDidInitialize = true
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.appDidInitialize, object: nil)
        
        if onboardingDidComplete, let pendingPushNotification = pendingPushNotification {
            didReceive(pushNotification: pendingPushNotification)
            self.pendingPushNotification = nil
        }
    }
    
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let payload = notification.request.content.userInfo
        let deliveryID = Self.deliveryID(for: notification)
        DispatchQueue.main.async { [weak self] in
            self?.receive(payload: payload, deliveryID: deliveryID, arrival: .default)
            completionHandler([])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let payload = response.notification.request.content.userInfo
        let deliveryID = Self.deliveryID(for: response.notification)
        let didOpen = response.actionIdentifier != UNNotificationDismissActionIdentifier
        DispatchQueue.main.async { [weak self] in
            if didOpen {
                self?.receive(payload: payload, deliveryID: deliveryID, arrival: .default)
            }
            completionHandler()
        }
    }
    
}

// MARK: -

private extension Bundle {
    
    func infoPlistValue(forKey key: String) -> String? {
        guard let value = self.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else { return nil }
        return value
    }
    
}
