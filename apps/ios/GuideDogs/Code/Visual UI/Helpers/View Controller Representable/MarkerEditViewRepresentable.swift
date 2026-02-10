//
//  MarkerEditViewRepresentable.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI

class MarkerEditViewRepresentable: ViewControllerRepresentable {
    
    // MARK: Parameters
    
    let config: EditMarkerConfig
    
    // MARK: Initialization
    
    @MainActor
    init(entity: POI, nickname: String?, annotation: String?, telemetryContext: String) {
        let importedDetail = ImportedLocationDetail(nickname: nickname, annotation: annotation)
        let locationDetail = LocationDetail(entity: entity, imported: importedDetail)
        
        config = EditMarkerConfig(detail: locationDetail,
                                  route: nil,
                                  context: telemetryContext,
                                  addOrUpdateAction: .popViewController,
                                  deleteAction: nil,
                                  leftBarButtonItemIsHidden: false)
    }
    
    @MainActor
    init(marker: RealmReferenceEntity, nickname: String?, annotation: String?, telemetryContext: String) {
        let importedDetail = ImportedLocationDetail(nickname: nickname, annotation: annotation)
        let locationDetail = LocationDetail(marker: marker, imported: importedDetail)
        
        config = EditMarkerConfig(detail: locationDetail,
                                  route: nil,
                                  context: telemetryContext,
                                  addOrUpdateAction: .popViewController,
                                  deleteAction: nil,
                                  leftBarButtonItemIsHidden: false)
    }
    
    init(config: EditMarkerConfig) {
        self.config = config
    }
    
    // MARK: `ViewControllerRepresentable`
    
    func makeViewController() -> UIViewController? {
        let navHelper = ViewNavigationHelper()
        let view = EditMarkerView(config: config).environmentObject(navHelper)
        let vc = UIHostingController(rootView: AnyView(view))
        navHelper.host = vc
        
        return vc
    }
    
}
