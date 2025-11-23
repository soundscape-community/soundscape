//
//  DeviceReachabilityAlertObserver.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

@MainActor
class DeviceReachabilityAlertObserver: NotificationObserver {
    
    // MARK: Properties
    
    weak var delegate: NotificationObserverDelegate?
    private(set) var didDismiss = false
    private var alert: UIAlertController?
    nonisolated private let dispatchQueue = DispatchQueue(label: "services.soundscape.device_reachability", qos: .background, attributes: .concurrent)
    nonisolated private let dispatchGroup = DispatchGroup()
    private var active: [DeviceReachability] = []
    
    // MARK: Initialization
    
    init() {
        // Find reachable devices
        // This work will be done on a background thread after 10
        // seconds
        pingAsync()
    }
    
    // MARK: Reachability
    
    private func pingAsync() {
        guard didDismiss == false else {
            // Alert has already been presented and dismissed
            return
        }
        
        // Add a 10 second delay to ensure that the alert is not displayed
        // immediately after app launch. Work executes on background queue, then
        // hops back to the main actor before touching state.
        dispatchQueue.asyncAfter(deadline: .now() + TimeInterval(10.0)) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.runReachabilityScan()
            }
        }
    }

    @MainActor
    private func runReachabilityScan() {
        guard didDismiss == false else {
            return
        }
        
        var reachableDevices: [DeviceType] = []
        
        DeviceType.allCases.forEach { device in
            guard let reachability = device.reachability else {
                // To ping a device, create a class that conforms to the
                // `DeviceReachability` API
                return
            }
            
            let didDismissNotification = FirstUseExperience.didComplete(.deviceReachabilityAlert(device: device))
            guard didDismissNotification == false else {
                // A reachability alert has already been presented for this device
                return
            }
            
            let didAddDevice = FirstUseExperience.didComplete(.addDevice(device: device))
            guard didAddDevice == false else {
                // Only present an alert if the user has not previously tried to connect to the device
                return
            }
            
            // Save a reference to each object until completion
            active.append(reachability)
            
            // All pings are sent off of the main thread and a dispatch group is used to wait for all devices to respond
            dispatchGroup.enter()
            
            reachability.ping(timeoutInterval: 1) { [weak self] isReachable in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    defer { self.dispatchGroup.leave() }
                    guard isReachable else {
                        // Device is not reachable
                        return
                    }
                    // Save as a reachable device
                    reachableDevices.append(device)
                }
            }
        }
        
        dispatchGroup.notify(queue: dispatchQueue) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.presentAlertIfNeeded(using: reachableDevices)
            }
        }
    }
    
    @MainActor
    private func presentAlertIfNeeded(using reachableDevices: [DeviceType]) {
        // Cleanup references after completion
        active = []
        
        // If more than one device is reachable (this is not a likely scenario)
        // then arbitrarily choose the first device
        guard let device = reachableDevices.first else {
            return
        }
        
        // Initialize reachability alert for the device
        let alert = UIAlertController(title: GDLocalizedString("devices.reachability.alert.title", "AirPods"),
                                      message: GDLocalizedString("devices.reachability.alert.description", "AirPods"),
                                      preferredStyle: .alert)
        
        // Add settings action
        let settingsAction = UIAlertAction(title: GDLocalizedString("settings.screen_title"),
                                           style: .default,
                                           handler: { [weak self] _ in
            guard let self = self else {
                return
            }
            
            GDATelemetry.track("head_tracking.device_available_alert.settings_selected", with: ["device": device.rawValue])
            
            // A device reachability alert should only be shown a maximum of once per session
            self.didDismiss = true
            
            // A device reachability alert should only be shown a maximum of once per device across all sessions
            FirstUseExperience.setDidComplete(for: .deviceReachabilityAlert(device: device))
            
            self.delegate?.performSegue(self, destination: AnyViewControllerRepresentable.manageDevices)
        })
        
        alert.addAction(settingsAction)
        alert.preferredAction = settingsAction
        
        // Add dismiss action
        let dismissAction = UIAlertAction(title: GDLocalizedString("general.alert.dismiss"),
                                          style: .cancel,
                                          handler: { [weak self] _ in
            guard let self = self else {
                return
            }
            
            GDATelemetry.track("head_tracking.device_available_alert.dismiss_selected", with: ["device": device.rawValue])
            
            // A device reachability alert should only be shown a maximum of once per session
            self.didDismiss = true
            
            // A device reachability alert should only be shown a maximum of once per device across all sessions
            FirstUseExperience.setDidComplete(for: .deviceReachabilityAlert(device: device))
        })
        
        alert.addAction(dismissAction)
        
        // Save reachability alert
        self.alert = alert
        
        // Notify the delegate
        self.delegate?.stateDidChange(self)
    }
    
    // MARK: `NotificationObserver`
    
    func notificationViewController(in viewController: UIViewController) -> UIViewController? {
        guard didDismiss == false else {
            return nil
        }
        
        guard let alert = alert else {
            return nil
        }
        
        return alert
    }
    
}
