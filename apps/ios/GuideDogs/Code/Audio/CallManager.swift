//
//  CallManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CallKit.CXCallObserver
import CocoaLumberjackSwift

enum CallStatusType: UInt {
    case began
    case ended
}

// MARK: Notifications

extension Notification.Name {
    static let callStatusChanged = Notification.Name("GDACallStatusChanged")
}

class CallManager: NSObject, CXCallObserverDelegate {
    
    // MARK: Keys
    
    struct Keys {
        static let callStatusTypeKey = "GDACallStatusTypeKey"
    }
    
    // MARK: Properties

    private let callObserver = CXCallObserver()
    private let callStateLock = NSLock()
    private var activeCall = false
    private(set) var callInProgress: Bool {
        get { callStateLock.withLock { activeCall } }
        set { callStateLock.withLock { activeCall = newValue } }
    }

    /// When a call ends while the app is inactive, we notify that the call ended only after the app becomes active.
    private var shouldNotifyCallEndedWhenAppIsActive = false
    
    // MARK: Initialization

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: .main)
        callInProgress = callObserver.calls.contains { !$0.hasEnded }
    }
    
    // MARK: CXCallObserverDelegate
    
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        DDLogInfo("[Call] Call status changed: <isOutgoing: \(call.isOutgoing)> <hasConnected: \(call.hasConnected)> <hasEnded: \(call.hasEnded)> <isOnHold: \(call.isOnHold)>")
        
        let hasActiveCall = callObserver.calls.contains { !$0.hasEnded }
        if callInProgress && !hasActiveCall {
            if AppContext.appState == .inactive {
                // "Call ended" will be handled when the app is active again
                shouldNotifyCallEndedWhenAppIsActive = true
                NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: NSNotification.Name.appDidBecomeActive, object: nil)
            } else {
                handleCallEnded()
            }
        } else if !callInProgress && hasActiveCall {
            handleCallStarted()
        }
    }
    
    // MARK: Actions

    private func handleCallStarted() {
        DDLogInfo("[Call] Handling call started")
        
        callInProgress = true
        
        // The beacon audio will be handled in the `DestinationManager` class
        AppContext.shared.eventProcessor.hush(playSound: false, hushBeacon: false)
        
        NotificationCenter.default.post(name: .callStatusChanged,
                                        object: self,
                                        userInfo: [CallManager.Keys.callStatusTypeKey: CallStatusType.began.rawValue])
    }
    
    private func handleCallEnded() {
        DDLogInfo("[Call] Handling call ended")

        callInProgress = false
        
        if shouldNotifyCallEndedWhenAppIsActive {
            NotificationCenter.default.removeObserver(self, name: .appDidBecomeActive, object: nil)
            shouldNotifyCallEndedWhenAppIsActive = false
        }
        
        NotificationCenter.default.post(name: .callStatusChanged,
                                        object: self,
                                        userInfo: [CallManager.Keys.callStatusTypeKey: CallStatusType.ended.rawValue])
    }
    
    @objc private func appDidBecomeActive(_ notification: Notification) {
        guard shouldNotifyCallEndedWhenAppIsActive, !callObserver.calls.contains(where: { !$0.hasEnded }) else {
            return
        }
        
        handleCallEnded()
    }
    
}
