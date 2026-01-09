//
//  MarkersList.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI
import RealmSwift
import CoreLocation

struct MarkersList: View {
    @EnvironmentObject var navHelper: MarkersAndRoutesListNavigationHelper
    
    @ObservedObject fileprivate var loader = MarkerLoader()
    
    @Binding private var sort: SortStyle
    
    @State private var showAlert: Bool = false
    @State private var alert: Alert?
    @State private var selectedDetail: LocationDetail?
    @State private var goToNavDestination: Bool = false {
        didSet {
            if goToNavDestination == false {
                selectedDetail = nil
            }
        }
    }
    
    private var routeIsActive: Bool {
        return AppContext.shared.eventProcessor.activeBehavior is RouteGuidance
    }
    
    init(sort style: Binding<SortStyle>) {
        _sort = style
        loader.load(sort: sort)
    }
    
    @ViewBuilder var selectedDetailView: some View {
        if let detail = selectedDetail {
            EditMarkerView(config: EditMarkerConfig(detail: detail, context: "markers_list", deleteAction: .popViewController))
                .environmentObject(ViewNavigationHelper(isActive: $goToNavDestination))
        }
    }
    
    var body: some View {
        if !loader.loadingComplete {
            LoadingMarkersOrRoutesView()
        } else if loader.markerIDs.isEmpty {
            EmptyMarkerOrRoutesView(.markers)
                .background(Color.quaternaryBackground)
                .onAppear {
                    GDATelemetry.trackScreenView("markers_list.empty")
                }
        } else {
            List {
                SortStyleCell(listName: GDLocalizedString("markers.title"), sort: _sort)
                    .plainListRowBackground(Color.quaternaryBackground)

                if routeIsActive {
                    ForEach(loader.markerIDs, id: \.self) { id in
                        markerRow(id)
                    }
                } else {
                    ForEach(loader.markerIDs, id: \.self) { id in
                        markerRow(id)
                    }
                    .onDelete { offsets in
                        guard let index = offsets.first else {
                            return
                        }

                        let id = loader.markerIDs[index]
                        alert = confirmationAlert(for: id)
                        showAlert = true
                    }
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.quaternaryBackground)
            .alert(isPresented: $showAlert, content: { alert ?? errorAlert() })
            
            NavigationLink(destination: selectedDetailView, isActive: $goToNavDestination) {
                EmptyView()
            }
            .accessibilityHidden(true)
            .onAppear {
                GDATelemetry.trackScreenView("markers_list")
            }
        }
    }
    
    func entity(for markerID: String) -> POI? {
        return SpatialDataCache.referenceEntityByKey(markerID)?.getPOI()
    }
    
    private func confirmationAlert(for markerID: String) -> Alert {
        return Alert.deleteMarkerAlert(markerId: markerID,
                                       deleteAction: {
                                           delete(markerID)
                                       },
                                       cancelAction: { })
    }
    
    private func errorAlert() -> Alert {
         Alert(title: GDLocalizedTextView("general.error.error_occurred"),
               message: GDLocalizedTextView("markers.action.deleted_error"),
               dismissButton: nil)
    }
    
    private func delete(_ id: String) {
        do {
            try loader.remove(id: id)
        } catch {
            alert = errorAlert()
            showAlert = true
        }
    }

    @ViewBuilder
    private func markerRow(_ id: String) -> some View {
        Button {
            selectedDetail = LocationDetail(markerId: id, telemetryContext: "markers_list")

            let storyboard = UIStoryboard(name: "POITable", bundle: Bundle.main)

            guard let viewController = storyboard.instantiateViewController(identifier: "LocationDetailView") as? LocationDetailViewController else {
                return
            }

            viewController.locationDetail = selectedDetail
            viewController.deleteAction = .popToViewController(type: MarkersAndRoutesListHostViewController.self)
            viewController.onDismissPreviewHandler = navHelper.onDismissPreviewHandler

            navHelper.pushViewController(viewController, animated: true)
        } label: {
            MarkerCell(model: MarkerModel(id: id))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .conditionalAccessibilityAction(routeIsActive == false, named: Text(LocationAction.beacon.text)) {
            if let poi = entity(for: id) {
                navHelper.didSelectLocationAction(.beacon, entity: poi)
            }
        }
        .conditionalAccessibilityAction(routeIsActive == false, named: Text(LocationAction.edit.text)) {
            selectedDetail = LocationDetail(markerId: id, telemetryContext: "markers_list")
            goToNavDestination = true
        }
        .conditionalAccessibilityAction(routeIsActive == false, named: Text(LocationAction.preview.text)) {
            if let poi = entity(for: id) {
                navHelper.didSelectLocationAction(.preview, entity: poi)
            }
        }
        .accessibilityAction(named: Text(LocationAction.share(isEnabled: true).text), {
            if let poi = entity(for: id) {
                navHelper.didSelectLocationAction(.share(isEnabled: true), entity: poi)
            }
        })
        .plainListRowBackground(Color.quaternaryBackground)
    }
}

struct MarkersList_Previews: PreviewProvider {
    static var previews: some View {
        Realm.bootstrap()
        AppContext.shared.geolocationManager.mockLocation(CLLocation.sample)
        
        return Group {
            MarkersList(sort: .constant(.distance))
            MarkersList(sort: .constant(.alphanumeric))
        }
        .environmentObject(MarkersAndRoutesListNavigationHelper())
    }
}
