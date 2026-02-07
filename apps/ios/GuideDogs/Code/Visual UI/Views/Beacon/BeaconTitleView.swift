//
//  BeaconTitleView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI
import CoreLocation
import SSGeo

struct BeaconTitleView: View {
    
    // MARK: Properties
    
    @EnvironmentObject var navHelper: ViewNavigationHelper
    
    let beacon: BeaconDetail
    let userLocation: SSGeoLocation?
    
    init(beacon: BeaconDetail, userLocation: SSGeoLocation?) {
        self.beacon = beacon
        self.userLocation = userLocation
    }
    
    // MARK: `Body`
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            // Title text
            beacon.labels.title.accessibleTextView
                .font(.footnote)
                .foregroundColor(Color.secondaryForeground)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .if(beacon.routeDetail == nil) { view in
                    view.accessibilityHidden(true)
                }
            
            Group {
                let nLabel = beacon.labels.name
                let dLabel = beacon.labels.distance(from: userLocation)
                let aLabel = nLabel.appending(dLabel, localizedSeparator: " ")
                
                Group {
                    Text(nLabel.text)
                        .font(.body)
                        .foregroundColor(Color.primaryForeground)
                    + Text("・")
                        .font(.footnote)
                        .foregroundColor(Color.yellowHighlight)
                    + Text(dLabel.text)
                        .font(.footnote)
                        .foregroundColor(Color.yellowHighlight)
                }
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(aLabel.accessibilityText ?? aLabel.text))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(GDLocalizedTextView("beacon.action.mute_unmute_beacon.acc_hint"))
        .accessibilityAction {
            BeaconActionHandler.toggleAudio()
        }
        .if(beacon.routeDetail == nil && beacon.locationDetail.isMarker == false) { view in
            // If the given location is not a marker, add an accessibility action
            // to create a marker at the location
            view.accessibilityAction(named: Text(BeaconAction.createMarker.text), {
                guard let viewController = BeaconActionHandler.createMarker(detail: beacon) else {
                    return
                }
                
                navHelper.pushViewController(viewController, animated: true)
            })
        }
        .if(beacon.routeDetail == nil) { view in
            view.accessibilityAction(named: Text(BeaconAction.callout.text), {
                BeaconActionHandler.callout(detail: beacon)
            })
        }
        .if(beacon.routeDetail == nil) { view in
            view.accessibilityAction(named: Text(BeaconAction.toggleAudio.text), {
                BeaconActionHandler.toggleAudio()
            })
        }
        .if(beacon.routeDetail == nil) { view in
            view.accessibilityAction(named: Text(BeaconAction.moreInformation.text), {
                BeaconActionHandler.moreInformation(detail: beacon, userLocation: userLocation)
            })
        }
        .if(beacon.routeDetail == nil) { view in
            view.accessibilityAction(named: Text(BeaconAction.remove(source: nil).text), {
                BeaconActionHandler.remove(detail: beacon)
            })
        }
    }
    
}

struct BeaconTitleView_Previews: PreviewProvider {
    
    static var userLocation: SSGeoLocation {
        return SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 47.640179, longitude: -122.111320))
    }
    
    static var locationDetail: LocationDetail {
        let location = CLLocation(latitude: 47.640179, longitude: -122.111320)
        let importedDetail = ImportedLocationDetail(nickname: "Home", annotation: "This is an annotation.")
        
        return LocationDetail(location: location, imported: importedDetail, telemetryContext: nil)
    }
    
    static var adaptiveSportsBehavior: RouteGuidance? {
        let route = RouteDetailsView_Previews.testSportRoute
        UIRuntimeProviderRegistry.ensureConfiguredForLaunchIfNeeded()
        guard let spatialData = UIRuntimeProviderRegistry.providers.uiSpatialDataContext(),
              let motion = UIRuntimeProviderRegistry.providers.uiMotionActivityContext() else {
            return nil
        }
        
        var state = RouteGuidanceState(id: route.id)
        state.totalTime = 60 * 27 + 41
        state.visited.append(0)
        state.waypointIndex = 1
        
        let guidance = RouteGuidance(route,
                                     spatialData: spatialData,
                                     motion: motion)
        guidance.state = state
        
        return guidance
    }
    
    static var previews: some View {
        
        Group {
            BeaconTitleView(beacon: BeaconDetail(locationDetail: locationDetail, isAudioEnabled: true), userLocation: userLocation)
                .padding(10.0)
            
            if let routeGuidance = adaptiveSportsBehavior,
               let routeBeacon = BeaconDetail(from: routeGuidance, isAudioEnabled: true) {
                BeaconTitleView(beacon: routeBeacon, userLocation: nil)
                    .padding(10.0)
            }
        }
        .background(Color.primaryBackground)
        
    }
    
}
