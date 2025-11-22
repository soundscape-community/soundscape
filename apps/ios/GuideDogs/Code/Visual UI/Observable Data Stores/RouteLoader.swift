//
//  RouteLoader.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine
import CoreLocation

@MainActor
class RouteLoader: ObservableObject {
    @Published var loadingComplete = false
    @Published var routeIDs: [String] = []
    
    private var currentSort: SortStyle = .alphanumeric
    private var tokens: [AnyCancellable] = []
    private var loadTask: Task<Void, Never>?
    
    deinit {
        tokens.cancelAndRemoveAll()
        loadTask?.cancel()
    }
    
    func load(sort: SortStyle) {
        currentSort = sort
        
        // Cancel any existing load operation
        loadTask?.cancel()
        
        loadTask = Task {
            let keys = await Route.asyncObjectKeys(sortedBy: sort)
            
            guard !Task.isCancelled else { return }
            
            // Initialize routes given the sorted keys (e.g. alphanumeric or distance)
            self.routeIDs = keys
            self.loadingComplete = true
            self.listenForNewRoutes()
        }
    }
    
    func remove(id: String) throws {
        guard let index = routeIDs.firstIndex(where: { $0 == id }) else {
            return
        }
        
        routeIDs.remove(at: index)
        
        try Route.delete(id)
        UIAccessibility.post(notification: .announcement, argument: GDLocalizedString("routes.action.deleted"))
    }
    
    private func listenForNewRoutes() {
        tokens.append(NotificationCenter.default.publisher(for: .routeAdded).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.load(sort: self.currentSort)
        })
        
        tokens.append(NotificationCenter.default.publisher(for: .routeDeleted).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.load(sort: self.currentSort)
        })
    }
}
