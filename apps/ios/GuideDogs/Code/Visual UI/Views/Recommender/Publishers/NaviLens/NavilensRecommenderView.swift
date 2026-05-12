//
//  NavilensRecommenderView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

struct NavilensRecommenderView: View {

    // MARK: Properties

    @EnvironmentObject var navHelper: ViewNavigationHelper

    let poi: POI

    // MARK: Body

    var body: some View {
        RecommenderContainerView(combinesAccessibilityChildren: false) {
            VStack(alignment: .leading, spacing: 12.0) {
                VStack(alignment: .leading, spacing: 4.0) {
                    GDLocalizedTextView("filter.navilens")
                        .font(.body)

                    Text(poi.localizedName)
                        .font(.title3)
                }

                VStack(spacing: 8.0) {
                    Button(action: { launchNaviLensApp() }, label: {
                        NavilensRecommenderActionLabel(image: Image("navilens"),
                                                       titleKey: "recommender.navilens.open")
                    })
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHint(GDLocalizedTextView("recommender.navilens.open.hint"))

                    Button(action: { showNearbyNaviLensCodes() }, label: {
                        NavilensRecommenderActionLabel(image: Image(systemName: "list.bullet"),
                                                       titleKey: "recommender.navilens.show_nearby")
                    })
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHint(GDLocalizedTextView("recommender.navilens.show_nearby.hint"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .foregroundColor(Color.primaryForeground)
        .accessibleTextFormat()
    }

    // MARK: Actions

    private func showNearbyNaviLensCodes() {
        let storyboard = UIStoryboard(name: "POITable", bundle: Bundle.main)

        guard let viewController = storyboard.instantiateViewController(identifier: "NearbyTableViewController") as? NearbyTableViewController else {
            GDLogAppError("Failed to instantiate NearbyTableViewController from POITable storyboard")
            assertionFailure("Failed to instantiate NearbyTableViewController from POITable storyboard")
            return
        }

        viewController.context = NearbyDataContext()
        viewController.currentFilter = NearbyTableFilter(type: .navilens)
        viewController.navigationItem.title = GDLocalizedString("filter.navilens")

        navHelper.pushViewController(viewController, animated: true)
    }

}

private struct NavilensRecommenderActionLabel: View {

    // MARK: Properties

    let image: Image
    let titleKey: String

    // MARK: Body

    var body: some View {
        HStack(spacing: 8.0) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: 24.0, height: 24.0)
                .accessibilityHidden(true)

            GDLocalizedTextView(titleKey)
                .font(.body)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0.0)
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 10.0)
        .frame(maxWidth: .infinity, minHeight: 44.0, alignment: .leading)
        .background(Color.primaryForeground.opacity(0.18))
        .cornerRadius(5.0)
    }

}
