//
//  MarkerCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine
import CoreLocation

@MainActor
class MarkerModel: ObservableObject {
    let id: String
    
    private var location: CLLocation?
    
    @Published private(set) var isNew: Bool = false
    @Published private(set) var name: String = ""
    @Published private(set) var address: String = ""
    @Published private(set) var distance: String = ""
    @Published private(set) var distanceAccessibilityLabel: String = ""
    
    private var tokens: [AnyCancellable] = []
    private var updateTask: Task<Void, Never>?
    
    var nameAccessibilityLabel: String {
        return isNew ? GDLocalizedString("markers.new_badge.acc_label", name) :  name
    }
    
    init(id: String) {
        self.id = id
        
        // Save initial value
        self.location = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        
        tokens.append(NotificationCenter.default.publisher(for: .markerUpdated).sink { [weak self] notification in
            guard id == notification.userInfo?[ReferenceEntity.Keys.entityId] as? String else {
                return
            }
            
            self?.update()
        })
        
        update()
    }
    
    deinit {
        tokens.cancelAndRemoveAll()
        updateTask?.cancel()
    }
    
    private func update() {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            guard let detail = await LocationDetail.load(markerId: id),
                  let poi = detail.entity else {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            isNew = detail.isNew
            name = detail.displayName
            address = detail.displayAddress

            updateDistance(for: poi)
        }
    }
    
    private func updateDistance(for poi: POI) {
        // Initialize `distance` and `direction` to an invalid value
        var distance = -1.0
        var direction = -1.0
        
        if let userLocation = location {
            distance = poi.distanceToClosestLocation(from: userLocation)
            direction = poi.bearingToClosestLocation(from: userLocation)
        }
        
        if distance > 0, direction.isValid {
            let cardinalDirection = CardinalDirection(direction: direction)!
            
            // "30 m・NW"
            self.distance = LanguageFormatter.string(from: distance, abbreviated: true) + "・" + cardinalDirection.localizedAbbreviatedString
            // "30 meters・North West"
            distanceAccessibilityLabel = LanguageFormatter.spellOutDistance(distance) + cardinalDirection.localizedString
        } else if distance >= 0 {
            // "30 m"
            self.distance = LanguageFormatter.string(from: distance, abbreviated: true)
            // "30 meters"
            distanceAccessibilityLabel = LanguageFormatter.spellOutDistance(distance)
        } else if direction.isValid {
            let cardinalDirection = CardinalDirection(direction: direction)!
            
            // "NW"
            self.distance = cardinalDirection.localizedAbbreviatedString
            // "North West"
            distanceAccessibilityLabel = cardinalDirection.localizedString
        }
    }
}

struct MarkerCell: View {
    
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 12.0
    @ObservedObject var model: MarkerModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if model.isNew {
                // icon
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: badgeSize, height: badgeSize)
                    .foregroundColor(.tertiaryForeground)
                    .padding([.top, .leading, .bottom], 20.0)
                    .accessibilityHidden(true)
            }
            
            // text section
            VStack(alignment: .leading) {
                Text(model.name)
                    .locationNameTextFormat()
                    .accessibilityLabel(Text(model.nameAccessibilityLabel))
                
                Text(model.distance)
                    .accessibilityLabel(Text(model.distanceAccessibilityLabel))
                    .locationDistanceTextFormat()
                
                Text(model.address)
                    .locationAddressTextFormat()
            }
            .locationCellTextPadding()
            
            Spacer()
            
            // accessory view
            Image(systemName: "chevron.right")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: badgeSize, height: badgeSize)
                .foregroundColor(.tertiaryForeground)
                .padding([.trailing])
                .accessibilityHidden(true)
        }
        .background(Color.primaryBackground)
        .accessibilityElement(children: .combine)
    }
}

struct MarkerCell_Previews: PreviewProvider {
    static var userLocationStore = UserLocationStore(designValue: CLLocation.sample.ssGeoLocation)
    
    static var previews: some View {
        SpatialPreviewSamples.bootstrap()
        
        return Group {
            MarkerCell(model: MarkerModel(id: SpatialPreviewSamples.sampleMarkerID()))
            MarkerCell(model: MarkerModel(id: SpatialPreviewSamples.secondarySampleMarkerID()))
        }
    }
}
