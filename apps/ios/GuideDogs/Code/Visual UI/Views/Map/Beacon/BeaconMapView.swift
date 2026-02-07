//
//  BeaconMapView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

struct BeaconMapView: View {
    
    // MARK: Properties
    
    @EnvironmentObject private var userLocationStore: UserLocationStore
    
    @State private var isMapDetailViewPresented = false
    @State private var isAnnotationDetailViewPresented = false
    @State private var selectedAnnotation: IdentifiableAnnotation?
    
    private let style: MapStyle
    
    private var config: LocationDetailConfiguration {
        LocationDetailConfiguration(for: style,
                                    userLocation: userLocationStore.ssGeoLocation,
                                    userLocationStore: userLocationStore)
    }
    
    // MARK: Initialization
    
    init(style: MapStyle) {
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 0.0) {
            HStack(spacing: 12.0) {
                NavigationLink {
                    config.detailView
                } label: {
                    LocationDetailHeader(config: config)
                }
                .accessibilityHint(GDLocalizedString("beacon.action.view_details.acc_hint.details"))
                
                Spacer()
            }
            
            Spacer()
            
            NavigationLink(isActive: $isAnnotationDetailViewPresented) {
                config.annotationDetailView(for: selectedAnnotation?.annotation)
            } label: {
                EmptyView()
            }
            .accessibilityHidden(true)
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            MapView(style: style) { annotation in
                guard let annotation = annotation as? WaypointDetailAnnotation else {
                    // Currently, detail view is only supported for waypoint annotations
                    return
                }
                
                selectedAnnotation = annotation.asIdentifiable
                isAnnotationDetailViewPresented = true
            }
            .ignoresSafeArea()
        )
        .navigationTitle(config.title)
    }
}

struct BeaconMapView_Previews: PreviewProvider {
    static let previewUserLocationStore = UserLocationStore()
    
    static var content: AuthoredActivityContent {
        let availability = DateInterval(start: Date(), duration: 60 * 60 * 24 * 7)
        
        let waypoints = [
            ActivityWaypoint(coordinate: .init(latitude: 47.622111, longitude: -122.341000), name: "Important Place", description: "This is a waypoint in an activity", departureCallout: nil, arrivalCallout: nil, images: [], audioClips: [])
        ]
        
        return AuthoredActivityContent(id: UUID().uuidString,
                                       type: .orienteering,
                                       name: GDLocalizationUnnecessary("Paddlepalooza"),
                                       creator: GDLocalizationUnnecessary("Our Team"),
                                       locale: Locale.enUS,
                                       availability: availability,
                                       expires: false,
                                       image: nil,
                                       desc: GDLocalizationUnnecessary("This is a fun event! There will be a ton to do. You should come join us!"),
                                       waypoints: waypoints, pois: [])
    }
    
    static var tourDetail: TourDetail {
        TourDetail(content: content)
    }

    static var behavior: GuidedTour {
        var state = TourState(id: tourDetail.id)
        state.totalTime = 60 * 27 + 41
        state.visited.append(0)
        state.waypointIndex = 1

        let behavior = GuidedTour(tourDetail,
                                  spatialData: AppContext.shared.spatialDataContext,
                                  motion: AppContext.shared.motionActivityContext)
        behavior.state = state
        return behavior
    }
    
    static var previews: some View {
        BeaconMapView(style: .tour(detail: tourDetail))
            .environmentObject(previewUserLocationStore)
        BeaconMapView(style: .location(detail: tourDetail.waypoints.first!))
            .environmentObject(previewUserLocationStore)
    }
    
}
