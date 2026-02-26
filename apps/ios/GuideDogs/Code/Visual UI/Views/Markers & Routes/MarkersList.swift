//
//  MarkersList.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import SwiftUI

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
        UIRuntimeProviderRegistry.providers.routeGuidanceStateStoreActiveRouteGuidance() != nil
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
            VStack(spacing: 0) {
                SortStyleCell(listName: GDLocalizedString("markers.title"), sort: _sort)
                
                ForEach(loader.markerIDs, id: \.self) { id in
                    MarkerCell(model: MarkerModel(id: id))
                        .accessibilityAddTraits(.isButton)
                        .conditionalAccessibilityAction(routeIsActive == false, named: Text(LocationAction.beacon.text)) {
                            didSelectLocationAction(.beacon, for: id)
                        }
                        .conditionalAccessibilityAction(routeIsActive == false, named: Text(LocationAction.edit.text)) {
                            didSelectEditAction(for: id)
                        }
                        .conditionalAccessibilityAction(routeIsActive == false, named: GDLocalizedTextView("general.alert.delete")) {
                            presentDeleteConfirmation(for: id)
                        }
                        .conditionalAccessibilityAction(routeIsActive == false, named: Text(LocationAction.preview.text)) {
                            didSelectLocationAction(.preview, for: id)
                        }
                        .accessibilityAction(named: Text(LocationAction.share(isEnabled: true).text), {
                            didSelectLocationAction(.share(isEnabled: true), for: id)
                        })
                        .if(routeIsActive == false, transform: {
                            $0.onDelete {
                                delete(id)
                            }
                        })
                        .onTapGesture {
                            didSelectMarker(for: id)
                        }
                }
            }
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
    
    @MainActor
    private func entity(for markerID: String) async -> POI? {
        guard let detail = await LocationDetail.load(markerId: markerID) else {
            return nil
        }

        return detail.entity
    }

    private func didSelectEditAction(for markerID: String) {
        Task { @MainActor in
            guard let detail = await LocationDetail.load(markerId: markerID,
                                                         telemetryContext: "markers_list") else {
                return
            }

            selectedDetail = detail
            goToNavDestination = true
        }
    }

    private func didSelectMarker(for markerID: String) {
        Task { @MainActor in
            guard let detail = await LocationDetail.load(markerId: markerID,
                                                         telemetryContext: "markers_list") else {
                return
            }

            let storyboard = UIStoryboard(name: "POITable", bundle: Bundle.main)

            guard let viewController = storyboard.instantiateViewController(identifier: "LocationDetailView") as? LocationDetailViewController else {
                return
            }

            selectedDetail = detail
            viewController.locationDetail = detail
            viewController.deleteAction = .popToViewController(type: MarkersAndRoutesListHostViewController.self)
            viewController.onDismissPreviewHandler = navHelper.onDismissPreviewHandler

            navHelper.pushViewController(viewController, animated: true)
        }
    }

    private func didSelectLocationAction(_ action: LocationAction, for markerID: String) {
        Task { @MainActor in
            guard let poi = await entity(for: markerID) else {
                return
            }

            navHelper.didSelectLocationAction(action, entity: poi)
        }
    }
    
    private func presentDeleteConfirmation(for markerID: String) {
        Task { @MainActor in
            let routeNames = await DataContractRegistry.spatialRead
                .routes(containingMarkerID: markerID)
                .map(\.name)
            alert = confirmationAlert(for: markerID, routeNames: routeNames)
            showAlert = true
        }
    }

    private func confirmationAlert(for markerID: String, routeNames: [String]) -> Alert {
        return Alert.deleteMarkerAlert(routeNames: routeNames,
                                       deleteAction: { delete(markerID) },
                                       cancelAction: { selectedDetail = nil })
    }
    
    private func errorAlert() -> Alert {
         Alert(title: GDLocalizedTextView("general.error.error_occurred"),
               message: GDLocalizedTextView("markers.action.deleted_error"),
               dismissButton: nil)
    }
    
    private func delete(_ id: String) {
        Task { @MainActor in
            do {
                try await loader.remove(id: id)
            } catch {
                alert = errorAlert()
                showAlert = true
            }
        }
    }
}

struct MarkersList_Previews: PreviewProvider {
    static var previews: some View {
        SpatialPreviewSamples.bootstrap()
        
        return Group {
            MarkersList(sort: .constant(.distance))
            MarkersList(sort: .constant(.alphanumeric))
        }
        .environmentObject(MarkersAndRoutesListNavigationHelper())
    }
}
