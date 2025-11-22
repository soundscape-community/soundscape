//
//  PersistentNotificationObserver.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

@MainActor
protocol PersistentNotificationObserver: NotificationObserver { }

extension PersistentNotificationObserver {
    
    var didDismiss: Bool {
        return false
    }
    
}
