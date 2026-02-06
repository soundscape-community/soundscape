//
//  UserLocationStore.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Combine
import CoreLocation
import SSGeo

@MainActor
enum UserLocationStoreRuntime {
    static func initialUserLocation() -> SSGeoLocation? {
        VisualRuntimeProviderRegistry.providers.userLocationStoreInitialUserLocation()
    }
}

@MainActor
class UserLocationStore: ObservableObject {
    @Published var ssGeoLocation: SSGeoLocation?
    
    private var listener: AnyCancellable?
    
    init() {
        listener = NotificationCenter.default.publisher(for: .locationUpdated).sink { [weak self] notification in
            guard let location = notification.userInfo?[SpatialDataContext.Keys.location] as? CLLocation else {
                return
            }
            
            self?.ssGeoLocation = location.ssGeoLocation
        }
        
        // Save initial value
        self.ssGeoLocation = UserLocationStoreRuntime.initialUserLocation()
    }

    init(designValue: SSGeoLocation) {
        ssGeoLocation = designValue
    }
    
    deinit {
        listener?.cancel()
        listener = nil
    }
}
