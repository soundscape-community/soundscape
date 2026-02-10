//
//  MarkerLoader.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Combine
import CoreLocation

@MainActor
class MarkerLoader: ObservableObject {
    @Published var loadingComplete = false
    @Published var markerIDs: [String] = []
    
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
            let entities = await DataContractRegistry.spatialRead.referenceEntities().filter { !$0.isTemp }
            let sortedKeys = sortedMarkerIDs(for: entities, sort: sort)
            
            guard !Task.isCancelled else { return }
            
            // Initialize markers sorted by the given predicate (e.g. alphanumeric or distance)
            self.markerIDs = sortedKeys
            self.loadingComplete = true
            self.listenForChanges()
        }
    }
    
    func remove(id: String) throws {
        guard let index = markerIDs.firstIndex(where: { $0 == id }) else {
            return
        }
        
        markerIDs.remove(at: index)
        
        try DataContractRegistry.spatialWriteCompatibility.removeReferenceEntity(id: id)
        UIAccessibility.post(notification: .announcement, argument: GDLocalizedString("markers.action.deleted"))
    }

    private func sortedMarkerIDs(for entities: [ReferenceEntity], sort: SortStyle) -> [String] {
        switch sort {
        case .alphanumeric:
            return entities.sorted(by: { $0.name < $1.name }).map(\.id)
        case .distance:
            let userLocation = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
                ?? CLLocation(latitude: 0.0, longitude: 0.0)
            return entities
                .sorted(by: { $0.distanceToClosestLocation(from: userLocation) < $1.distanceToClosestLocation(from: userLocation) })
                .map(\.id)
        }
    }
    
    private func listenForChanges() {
        tokens.append(NotificationCenter.default.publisher(for: .markerAdded).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.load(sort: self.currentSort)
        })
        
        tokens.append(NotificationCenter.default.publisher(for: .markerRemoved).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self = self else { return }
            self.load(sort: self.currentSort)
        })
    }
}
