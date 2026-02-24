//
//  LocationActionHandler.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import MapKit

@MainActor
struct LocationActionHandler {
    
    // MARK: `typealias`
    
    typealias PreviewResult = Result<PreviewBehavior<IntersectionDecisionPoint>, LocationActionError>
    typealias PreviewCompletion = (PreviewResult) -> Void
    
    // MARK: `LocationAction` Methods
    
    static func save(locationDetail: LocationDetail) async throws {
        let markerId: String?
        
        switch locationDetail.source {
        case .entity(let id):
            let nickname = locationDetail.nickname
            let estimatedAddress = locationDetail.estimatedAddress
            let annotation = locationDetail.annotation
            
            markerId = try? await DataContractRegistry.spatialWrite.addReferenceEntity(entityKey: id,
                                                                                        nickname: nickname,
                                                                                        estimatedAddress: estimatedAddress,
                                                                                        annotation: annotation)
        case .coordinate:
            let latitude = locationDetail.location.coordinate.latitude
            let longitude = locationDetail.location.coordinate.longitude
            let nickname = locationDetail.nickname
            let estimatedAddress = locationDetail.estimatedAddress
            let annotation = locationDetail.annotation
            
            let genericLocation = GenericLocation(lat: latitude, lon: longitude)
            
            markerId = try? await DataContractRegistry.spatialWrite.addReferenceEntity(location: genericLocation,
                                                                                        nickname: nickname,
                                                                                        estimatedAddress: estimatedAddress,
                                                                                        annotation: annotation)
            
        case .designData:
            markerId = nil
            
        case .screenshots:
            markerId = nil
        }
        
        guard let markerId = markerId,
              await DataContractRegistry.spatialRead.referenceMetadata(byID: markerId) != nil else {
            throw LocationActionError.failedToSaveMarker
        }
        
        // Save selection
        locationDetail.updateLastSelectedDate()
    }
    
    static func beacon(locationDetail: LocationDetail) async throws {
        do {
            switch locationDetail.source {
            case .entity(let id):
                // Set a beacon on the given entity
                try await beacon(entityId: id)
                
            case .coordinate:
                let location = locationDetail.location
                let name = locationDetail.displayName
                let address = locationDetail.estimatedAddress
                
                // Set a beacon on the given coordinate
                try await beacon(location: location, name: name, address: address)
                
            case .designData:
                break
                
            case .screenshots(let poi):
                try await beacon(location: poi.location, name: poi.name, address: poi.addressLine)
            }
        } catch {
            throw LocationActionError.failedToSetBeacon
        }
        
        // Save selection
        locationDetail.updateLastSelectedDate()
    }
    
    static private func beacon(entityId: String) async throws {
        guard let manager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            throw LocationActionError.failedToSetBeacon
        }
        let userLocation = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        
        _ = try await manager.setDestinationAsync(entityKey: entityId,
                                                  enableAudio: true,
                                                  userLocation: userLocation,
                                                  estimatedAddress: nil,
                                                  logContext: "location_action")
    }
    
    static private func beacon(location: CLLocation, name: String, address: String?) async throws {
        guard let manager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            throw LocationActionError.failedToSetBeacon
        }
        let userLocation = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        
        let gLocation = GenericLocation(lat: location.coordinate.latitude, lon: location.coordinate.longitude, name: name)
        _ = try await manager.setDestinationAsync(location: gLocation,
                                                  address: address,
                                                  enableAudio: true,
                                                  userLocation: userLocation,
                                                  logContext: "location_action")
    }
    
    static func preview(locationDetail: LocationDetail, completion: @escaping PreviewCompletion) -> Progress? {
        // Save selection
        locationDetail.updateLastSelectedDate()

        guard let spatialDataContext = UIRuntimeProviderRegistry.providers.uiSpatialDataContext() else {
            completion(.failure(.failedToStartPreview))
            return nil
        }

        return spatialDataContext.updateSpatialData(at: locationDetail.location) {
            guard let intersection = ReverseGeocoderContext.closestIntersection(for: locationDetail) else {
                GDATelemetry.track("preview.error.closest_intersection_not_found")
                completion(.failure(.failedToStartPreview))
                return
            }
            
            let decisionPoint = IntersectionDecisionPoint(node: intersection)
            
            guard decisionPoint.edges.count > 0 else {
                GDATelemetry.track("preview.error.edges_not_found")
                completion(.failure(.failedToStartPreview))
                return
            }

            guard let geolocationManager = UIRuntimeProviderRegistry.providers.uiGeolocationManager(),
                  let audioEngine = UIRuntimeProviderRegistry.providers.uiAudioEngine() else {
                completion(.failure(.failedToStartPreview))
                return
            }
            
            let behavior = PreviewBehavior(at: decisionPoint,
                                           from: locationDetail,
                                           geolocationManager: geolocationManager,
                                           destinationManager: spatialDataContext.destinationManager,
                                           audioEngine: audioEngine)
            
            completion(.success(behavior))
        }
    }
    
    static func share(locationDetail: LocationDetail) throws -> URL {
        guard let url = UniversalLinkManager.shareLocation(locationDetail) else {
            throw LocationActionError.failedToShare
        }
        
        // Save selection
        locationDetail.updateLastSelectedDate()
        
        return url
    }
    
}
