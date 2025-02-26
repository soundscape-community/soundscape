//
//  Integrations.swift
//  GuideDogs
//
//  Created by Daniel W. Steinbrook on 2/25/25.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

func launchNaviLens() {
    // FIXME launch NaviLens app
    let navilensUrl = URL(string: "https://www.navilens.com/en/")!
    UIApplication.shared.open(navilensUrl) { success in
        if !success {
            UIApplication.shared.open(URL(string: "https://apps.apple.com/us/app/navilens/id1273704914")!)
        }
    }
}
