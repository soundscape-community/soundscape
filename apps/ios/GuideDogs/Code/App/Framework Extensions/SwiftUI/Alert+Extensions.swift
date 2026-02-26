//
//  Alert+Extensions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import SwiftUI

@MainActor
extension Alert {
    
    static func deleteMarkerAlert(routeNames: [String],
                                  deleteAction: @escaping (() -> Void),
                                  cancelAction: @escaping (() -> Void) = {}) -> Alert {
        let message: Text
        if routeNames.isEmpty {
            message = GDLocalizedTextView("general.alert.destructive_undone_message")
        } else {
            let joinedRouteNames = routeNames.joined(separator: "\n")
            message = GDLocalizedTextView("markers.destructive_delete_message.routes", joinedRouteNames)
        }
        
        return Alert(title: GDLocalizedTextView("markers.destructive_delete_message"),
                     message: message,
                     primaryButton: .cancel(GDLocalizedTextView("general.alert.cancel"), action: cancelAction),
                     secondaryButton: .destructive(GDLocalizedTextView("general.alert.delete"), action: deleteAction))
    }
    
}
