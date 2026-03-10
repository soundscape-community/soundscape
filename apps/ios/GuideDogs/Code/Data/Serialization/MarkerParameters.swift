//
//  MarkerParameters.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

enum ImportMarkerError: Error {
    case invalidParameter
    case entityNotFound
    case unableToImportLocalEntity
    case failedToFetchMarker
}

@MainActor
struct MarkerParameters: Codable {
    
    // MARK: Properties
    
    /// Refers to the saved marker id, if applicable.
    let id: String?
    let nickname: String?
    let annotation: String?
    let estimatedAddress: String?
    let lastUpdatedDate: Date?

    // `UniversalLinkParameter` Properties
    let location: LocationParameters
    
    // MARK: Initialization
    
    init?(entity: POI, markerId: String?, estimatedAddress: String?, nickname: String?, annotation: String?, lastUpdatedDate: Date?) {
        let location: LocationParameters
        
        if let entity = entity as? GDASpatialDataResultEntity {
            let id = entity.key
            let name = entity.localizedName
            let address = entity.addressLine
            let coordinate = CoordinateParameters(latitude: entity.centroidLatitude, longitude: entity.centroidLongitude)
            
            // Initialize parameters for an OSM entity
            let entityParameters = EntityParameters(source: .osm, lookupInformation: id)
            
            // Initialize location parameters
            location = LocationParameters(name: name, address: address, coordinate: coordinate, entity: entityParameters)
        } else {
            let coordinate = CoordinateParameters(latitude: entity.centroidLatitude, longitude: entity.centroidLongitude)
            
            // Initialize location parameters
            location = LocationParameters(name: entity.localizedName, address: nil, coordinate: coordinate, entity: nil)
        }
        
        if let markerId = markerId, markerId.isEmpty == false {
            self.id = markerId
        } else {
            self.id = nil
        }
        
        if let nickname = nickname, nickname.isEmpty == false {
            self.nickname = nickname
        } else {
            self.nickname = nil
        }
        
        if let annotation = annotation, annotation.isEmpty == false {
            self.annotation = annotation
        } else {
            self.annotation = nil
        }
        
        if let estimatedAddress = estimatedAddress, estimatedAddress.isEmpty == false {
            self.estimatedAddress = estimatedAddress
        } else {
            self.estimatedAddress = nil
        }
        
        self.lastUpdatedDate = lastUpdatedDate
        self.location = location
    }
    
    init?(marker: ReferenceEntity) {
        let entity = marker.getPOI()
        let markerId = marker.id
        let estimatedAddress = marker.estimatedAddress
        let nickname = marker.nickname
        let annotation = marker.annotation
        let lastUpdatedDate = marker.lastUpdatedDate
        
        self.init(entity: entity, markerId: markerId, estimatedAddress: estimatedAddress, nickname: nickname, annotation: annotation, lastUpdatedDate: lastUpdatedDate)
    }

    init?(markerId: String) {
        guard let marker = LocationDetailStoreAdapter.referenceEntity(byID: markerId) else {
            return nil
        }

        let locationCoordinate = CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
        let locationMarker = LocationDetailStoreAdapter.referenceEntity(byLocation: locationCoordinate)
        let resolvedMarker = locationMarker ?? marker

        self.init(entity: resolvedMarker.getPOI(),
                  markerId: markerId,
                  estimatedAddress: resolvedMarker.estimatedAddress,
                  nickname: resolvedMarker.nickname,
                  annotation: resolvedMarker.annotation,
                  lastUpdatedDate: resolvedMarker.lastUpdatedDate)
    }
    
    init?(entity: POI) {
        let matchedMarker: ReferenceEntity?
        if let location = entity as? GenericLocation {
            matchedMarker = LocationDetailStoreAdapter.referenceEntity(byLocation: location.location.coordinate)
        } else {
            matchedMarker = LocationDetailStoreAdapter.referenceEntity(byEntityKey: entity.key)
        }

        if let matchedMarker {
            let markerID = matchedMarker.isTemp ? nil : matchedMarker.id
            self.init(entity: entity,
                      markerId: markerID,
                      estimatedAddress: matchedMarker.estimatedAddress,
                      nickname: matchedMarker.nickname,
                      annotation: matchedMarker.annotation,
                      lastUpdatedDate: matchedMarker.lastUpdatedDate)
            return
        }

        self.init(entity: entity,
                  markerId: nil,
                  estimatedAddress: nil,
                  nickname: nil,
                  annotation: nil,
                  lastUpdatedDate: nil)
    }
    
    init(name: String, latitude: Double, longitude: Double) {
        let coordinate = CoordinateParameters(latitude: latitude, longitude: longitude)
        let location = LocationParameters(name: name, address: nil, coordinate: coordinate, entity: nil)
        
        self.id = nil
        self.nickname = nil
        self.annotation = nil
        self.estimatedAddress = nil
        self.lastUpdatedDate = nil
        self.location = location
    }
    
}

extension MarkerParameters: UniversalLinkParameters {
    
    private struct Name {
        static let nickname = "nickname"
        static let annotation = "annotation"
    }
    
    // MARK: Properties
    
    var queryItems: [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
    
        if let nickname = nickname {
            // Append nickname
            queryItems.append(URLQueryItem(name: Name.nickname, value: nickname))
        }
        
        if let annotation = annotation {
            // Append annotation
            queryItems.append(URLQueryItem(name: Name.annotation, value: annotation))
        }
        
        // Append location query items
        queryItems.append(contentsOf: location.queryItems)
        
        return queryItems
    }
    
    // MARK: Initialization
    
    init?(queryItems: [URLQueryItem]) {
        guard let location = LocationParameters(queryItems: queryItems) else {
            return nil
        }
        
        self.id = nil
        self.nickname = queryItems.first(where: { $0.name == Name.nickname })?.value
        self.annotation = queryItems.first(where: { $0.name == Name.annotation })?.value
        // `estimatedAddress` is not used in universal links
        self.estimatedAddress = nil
        self.lastUpdatedDate = nil
        self.location = location
    }
    
}
