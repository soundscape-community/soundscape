//
//  Integrations.swift
//  GuideDogs
//
//  Created by Daniel W. Steinbrook on 2/25/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

@MainActor
func launchNaviLens(detail: LocationDetail) {
    // Silence Soundscape before launching NaviLens
    // Find the home screen in the view stack and trigger the sleep button
    let rootVc = AppContext.rootViewController as? UINavigationController;
    let homeVc = rootVc?.viewControllers.first as? HomeViewController;
    homeVc?.onSleepTouchUpInside();
    
    // Launch NaviLens app, or open App Store listing if not installed
    let navilensUrl = URL(string: "navilens://")!
    let appStoreUrl = URL(string: "https://apps.apple.com/us/app/navilens/id1273704914")!
    if UIApplication.shared.canOpenURL(navilensUrl) {
        UIApplication.shared.open(navilensUrl)
    } else {
        UIApplication.shared.open(appStoreUrl)
    }
}

@MainActor
func guideToNaviLens(detail: LocationDetail) throws {
    // Launch NaviLens if close enough, otherwise start beacon
    guard let location = AppContext.shared.geolocationManager.location else {
        // Location is unknown
        return launchNaviLens(detail: detail)
    }

    // If our GPS is more precise than we are close, use a beacon
    if location.coordinate.distance(from: detail.location.coordinate) > location.horizontalAccuracy {
        try LocationActionHandler.beacon(locationDetail: detail)
    } else {
        launchNaviLens(detail: detail)
    }
}

@MainActor
func safeGuideToNaviLens(poi: POI) {
    // Launch NaviLens if starting a beacon throws an error
    let detail = LocationDetail(entity: poi)
    do {
        try guideToNaviLens(detail: detail)
    } catch {
        launchNaviLens(detail: detail)
    }
}
