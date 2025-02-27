//
//  Integrations.swift
//  GuideDogs
//
//  Created by Daniel W. Steinbrook on 2/25/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

func launchNaviLens() {
    // Launch NaviLens app, or open App Store listing if not installed
    let navilensUrl = URL(string: "navilens://")!
    let appStoreUrl = URL(string: "https://apps.apple.com/us/app/navilens/id1273704914")!
    if UIApplication.shared.canOpenURL(navilensUrl) {
        UIApplication.shared.open(navilensUrl)
    } else {
        UIApplication.shared.open(appStoreUrl)
    }
}
