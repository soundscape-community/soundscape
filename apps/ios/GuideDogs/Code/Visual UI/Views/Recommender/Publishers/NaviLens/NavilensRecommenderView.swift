//
//  NavilensRecommenderView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community.
//  Licensed under the MIT License.
//

import SwiftUI

struct NavilensRecommenderView: View {
    
    // MARK: Properties
    
    @EnvironmentObject var navHelper: ViewNavigationHelper
        
    let poi: POI
    
    // MARK: Body
    
    var body: some View {
        Button(action: { safeGuideToNaviLens(poi: poi) }, label: {
            RecommenderContainerView {
                VStack(alignment: .leading, spacing: 4.0) {
                    GDLocalizedTextView("location_detail.action.beacon_or_navilens")
                        .font(.body)

                    Text(poi.localizedName)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .foregroundColor(Color.primaryForeground)
            .accessibleTextFormat()
        })
    }
    
}
