//
//  LaunchHelper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import CocoaLumberjackSwift
import SwiftUI

extension Notification.Name {
    static let appDidInitialize = Notification.Name("GDAAppDidInitialize")
    static let rebuildHome = Notification.Name("GDARebuildHome")
    static let magicTapOccurred = Notification.Name("GDAMagicTapOccurred")
}

class LaunchHelper {
    
    static weak var homePresenter: UIViewController?
    static weak var homeNavigationController: NavigationController?

    fileprivate static weak var configuredWindow: UIWindow?
    fileprivate static var magicTapEnabled: Bool = true

    @discardableResult
    class func performMagicTap() -> Bool {
        guard magicTapEnabled else {
            return false
        }

        AppContext.shared.eventProcessor.toggleAudio()
        NotificationCenter.default.post(name: .magicTapOccurred, object: self)

        return true
    }
    
    static func rebuildHome() {
        NotificationCenter.default.post(name: .rebuildHome, object: nil)
    }
}

extension UIWindow {
    // MARK: Configuration
    
    func configureForSoundscape() {
        guard LaunchHelper.configuredWindow !== self else {
            return
        }
        
        self.isOpaque = true
        self.backgroundColor = UIColor.black
        self.clipsToBounds = true
        
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(self.handleMagicTap))
        doubleTapGR.numberOfTapsRequired = 2
        doubleTapGR.numberOfTouchesRequired = 2
        self.addGestureRecognizer(doubleTapGR)
        
        NotificationCenter.default.addObserver(self, selector: #selector(disableMagicTap), name: NSNotification.Name.disableMagicTap, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enableMagicTap), name: NSNotification.Name.enableMagicTap, object: nil)
        
        LaunchHelper.configuredWindow = self
    }
    
    // MARK: Actions
    
    override open func accessibilityPerformMagicTap() -> Bool {
        return handleMagicTap()
    }
    
    @objc fileprivate func handleMagicTap() -> Bool {
        LaunchHelper.performMagicTap()
    }
    
    @objc func disableMagicTap() {
        LaunchHelper.magicTapEnabled = false
    }
    
    @objc func enableMagicTap() {
        LaunchHelper.magicTapEnabled = true
    }

    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if(motion == .motionShake && SettingsContext.shared.shakeCalloutsEnabled){
            
            guard let callout = AppContext.shared.calloutHistory.callouts.last else {
                return
            }

            AppContext.process(RepeatCalloutEvent(callout: callout) { (_) in
            })
            
            return
        }
            
        
        
        // We use the shake motion to pause and resume a GPX simulation
        guard FeatureFlag.isEnabled(.developerTools),
            motion == .motionShake,
            AppContext.shared.geolocationManager.isSimulatingGPX else {
                return
        }
        
        DDLogInfo("Shake motion detected")
        
        guard let gpxSimulator = AppContext.shared.geolocationManager.gpxSimulator else { return }
        gpxSimulator.toggleSimulationState()
        
        let generator = UINotificationFeedbackGenerator()
        
        if gpxSimulator.isPaused {
            generator.notificationOccurred(.error)
        } else {
            generator.notificationOccurred(.success)
        }
    }
    
}
