//
//  Samplable.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SSData
import CoreLocation

protocol Samplable {
    associatedtype Item
    static var sample: Item { get }
    static var samples: [Item] { get }
}

extension CLLocation: Samplable {
    static var samples: [CLLocation] { [sample] }
    
    static var sample: CLLocation {
        // Near 9th Ave N and Harrison in SLU Seattle
        CLLocation(latitude: 47.622491, longitude: -122.339840)
    }
}

extension ReferenceEntity: Samplable {
    static var samples: [ReferenceEntity] { [sample, sample2, sample3, sample4] }
    
    static var sample: ReferenceEntity {
        let entity = ReferenceEntity(location: .init(lat: 47.622918, lon: -122.338521, name: "Republic"),
                        name: "Republic",
                        estimatedAddress: "429 Westlake Ave N, Seattle, WA 98109",
                        annotation: "This is my favorite restaurant",
                        temp: false)
        entity.id = PreviewStorage.markerIDs[0]
        return entity
    }
    
    static var sample2: ReferenceEntity {
        let entity = ReferenceEntity(location: .init(lat: 47.618433, lon: -122.338346, name: "Whole Foods"),
                        name: "Grocery Store",
                        estimatedAddress: nil,
                        annotation: nil,
                        temp: false)
        entity.id = PreviewStorage.markerIDs[1]
        return entity
    }
    
    static var sample3: ReferenceEntity {
        let entity = ReferenceEntity(location: .init(lat: 47.620226, lon: -122.349204),
                                     name: "Space Needle",
                                     estimatedAddress: "400 Broad St, Seattle, WA 98109",
                                     annotation: nil,
                                     temp: false)
        entity.isNew = false
        entity.id = PreviewStorage.markerIDs[2]
        return entity
    }
    
    static var sample4: ReferenceEntity {
        let entity = ReferenceEntity(location: .init(lat: 47.627578, lon: -122.337055),
                                     name: "Museum of History & Industry",
                                     estimatedAddress: nil,
                                     annotation: nil,
                                     temp: false)
        entity.isNew = false
        entity.id = PreviewStorage.markerIDs[3]
        return entity
    }
}

extension RouteWaypoint: Samplable {
    static var samples: [RouteWaypoint] { [sample, sample2, sample3, sample4] }
    
    static var sample: RouteWaypoint { sample(at: 0) }
    static var sample2: RouteWaypoint { sample(at: 1) }
    static var sample3: RouteWaypoint { sample(at: 2) }
    static var sample4: RouteWaypoint { sample(at: 3) }

    private static func sample(at index: Int) -> RouteWaypoint {
        RouteWaypoint(stored: Waypoint(markerId: PreviewStorage.markerIDs[index], index: index))
    }
}

extension Route: Samplable {
    static var samples: [Route] { [sample] }
    
    static var sample: Route {
        let route = Route(name: "Seattle Sightseeing Tour", description: "This is a little walk through Seattle's South Lake Union neighborhood", waypoints: RouteWaypoint.samples)
        route.id = "preview-route"
        return route
    }
}

enum PreviewStorage {
    static let markerIDs = ["preview-republic", "preview-grocery", "preview-needle", "preview-museum"]

    static func bootstrap() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" else { return }
        do {
            try StorageContext.shared.saveRoute(Route.sample.saved, importing: ReferenceEntity.samples.map(\.stored))
        } catch {
            GDLogAppError("Unable to prepare preview storage: \(error)")
        }
    }
}
