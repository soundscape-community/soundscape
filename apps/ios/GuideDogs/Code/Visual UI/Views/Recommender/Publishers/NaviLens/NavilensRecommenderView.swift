//
//  NavilensRecommenderView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

private let navilensRecommenderTelemetryContext = "navilens_recommender"

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

                    Button(action: { showLocationDetail() }, label: {
                        HStack(spacing: 8.0) {
                            Text(poi.localizedName)
                                .font(.title3)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0.0)

                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 12.0)
                        .padding(.vertical, 10.0)
                        .frame(maxWidth: .infinity, minHeight: 44.0, alignment: .leading)
                        .background(Color.primaryForeground.opacity(0.18))
                        .cornerRadius(5.0)
                    })
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHint(GDLocalizedTextView("location.select.hint"))
                    .accessibilityLocationActions(LocationAction.enabledAccessibilityActions(for: poi)) { action in
                        (navHelper as? RecommenderNavigationHelper)?.didSelectLocationAction(action, entity: poi)
                    }
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

    private func showLocationDetail() {
        let storyboard = UIStoryboard(name: "POITable", bundle: Bundle.main)

        guard let viewController = storyboard.instantiateViewController(identifier: "LocationDetailView") as? LocationDetailViewController else {
            GDLogAppError("Failed to instantiate LocationDetailViewController from POITable storyboard")
            assertionFailure("Failed to instantiate LocationDetailViewController from POITable storyboard")
            return
        }

        viewController.locationDetail = LocationDetail(entity: poi, telemetryContext: navilensRecommenderTelemetryContext)

        navHelper.pushViewController(viewController, animated: true)
    }

}

class RecommenderNavigationHelper: ViewNavigationHelper, LocationAccessibilityActionDelegate {

    func didSelectLocationAction(_ action: LocationAction, entity: POI) {
        GDATelemetry.track(action.telemetryEvent, with: ["context": navilensRecommenderTelemetryContext, "source": "accessibility_action"])

        let detail = LocationDetail(entity: entity, telemetryContext: navilensRecommenderTelemetryContext)

        LocationDetail.fetchNameAndAddressIfNeeded(for: detail) { [weak self] (newValue) in
            guard let `self` = self else {
                return
            }

            self.didSelectLocationAction(action, detail: newValue)
        }
    }

    private func didSelectLocationAction(_ action: LocationAction, detail: LocationDetail) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }

            guard action.isEnabled else {
                return
            }

            do {
                switch action {
                case .save, .edit:
                    let config = EditMarkerConfig(detail: detail,
                                                  route: nil,
                                                  context: navilensRecommenderTelemetryContext,
                                                  addOrUpdateAction: .popViewController,
                                                  deleteAction: .popViewController,
                                                  leftBarButtonItemIsHidden: false)

                    if let viewController = MarkerEditViewRepresentable(config: config).makeViewController() {
                        self.pushViewController(viewController, animated: true)
                    }

                case .beacon:
                    try LocationActionHandler.beacon(locationDetail: detail)
                    self.popToRootViewController(animated: true)

                case .preview:
                    let previewPresenter = self.previewPresenter

                    if AppContext.shared.isStreetPreviewing {
                        let alert = LocationActionAlert.restartPreview { [weak self] (_) in
                            self?.previewPresenter?.performSegue(withIdentifier: "PreviewView", sender: detail)
                        }

                        previewPresenter?.present(alert, animated: true, completion: nil)
                    } else {
                        previewPresenter?.performSegue(withIdentifier: "PreviewView", sender: detail)
                    }

                case .share:
                    let url = try LocationActionHandler.share(locationDetail: detail)
                    let alert = ShareMarkerAlert.shareMarker(url, markerName: detail.displayName)

                    if FirstUseExperience.didComplete(.share) {
                        self.host?.present(alert, animated: true, completion: nil)
                    } else {
                        let firstUseAlert = ShareMarkerAlert.firstUseExperience(dismissHandler: { [weak self] _ in
                            guard let `self` = self else {
                                return
                            }

                            FirstUseExperience.setDidComplete(for: .share)

                            self.host?.present(alert, animated: true, completion: nil)
                        })

                        self.host?.present(firstUseAlert, animated: true, completion: nil)
                    }

                case .navilens:
                    launchNaviLens(detail: detail)
                    self.popToRootViewController(animated: true)
                }
            } catch let error as LocationActionError {
                let alert = LocationActionAlert.alert(for: error)
                self.host?.present(alert, animated: true, completion: nil)
            } catch {
                let alert = LocationActionAlert.alert(for: error)
                self.host?.present(alert, animated: true, completion: nil)
            }
        }
    }

    private var previewPresenter: UIViewController? {
        var viewController = host as UIViewController?

        while let current = viewController {
            if current is HomeViewController {
                return current
            }

            viewController = current.parent
        }

        return nil
    }

}

private struct LocationActionAccessibilityActions: ViewModifier {

    let actions: [LocationAction]
    let handler: (LocationAction) -> Void

    func body(content: Content) -> some View {
        actions.reduce(AnyView(content)) { view, action in
            AnyView(view.accessibilityAction(named: Text(action.text)) {
                handler(action)
            })
        }
    }

}

private extension View {

    func accessibilityLocationActions(_ actions: [LocationAction], handler: @escaping (LocationAction) -> Void) -> some View {
        modifier(LocationActionAccessibilityActions(actions: actions, handler: handler))
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
