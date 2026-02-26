//
//  RouteCell.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine

@MainActor
class RouteModel: ObservableObject {
    let id: String
    
    @Published private(set) var isNew: Bool = false
    @Published private(set) var isActive: Bool = false
    @Published private(set) var name: String = ""
    @Published private(set) var description: String?
    
    private var tokens: [AnyCancellable] = []
    private var updateTask: Task<Void, Never>?
    
    var nameAccessibilityLabel: String {
        return isNew ? GDLocalizedString("markers.new_badge.acc_label", name) :  name
    }
    
    init(id: String) {
        self.id = id
        
        tokens.append(NotificationCenter.default.publisher(for: .routeUpdated).sink { [weak self] notification in
            guard id == notification.userInfo?[Route.Keys.id] as? String else {
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
        updateTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            guard let route = await DataContractRegistry.spatialRead.route(byKey: id) else {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            isNew = route.isNew
            isActive = route.isActive
            name = route.name
            description = route.routeDescription
        }
    }
}

struct RouteCell: View {
    
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 12.0
    
    @ObservedObject var model: RouteModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if model.isNew {
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: badgeSize, height: badgeSize)
                    .foregroundColor(.tertiaryForeground)
                    .padding([.top, .leading, .bottom], 20.0)
                    .accessibilityHidden(true)
            } else if model.isActive {
                AnimatedBeaconIcon(color: Color.yellowHighlight)
                    .frame(width: badgeSize, height: badgeSize)
                    .padding([.top, .leading, .bottom], 20.0)
                    .accessibilityLabel(GDLocalizedTextView("behavior.experience.badges.active"))
            }
            
            // text section
            VStack(alignment: .leading) {
                Text(model.name)
                    .locationNameTextFormat()
                    .accessibilityLabel(Text(model.nameAccessibilityLabel))
                
                if let desc = model.description {
                    Text(desc)
                        .locationDistanceTextFormat()
                }
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

struct RouteCell_Previews: PreviewProvider {
    static var previews: some View {
        SpatialPreviewSamples.bootstrap()
        
        return Group {
            RouteCell(model: RouteModel(id: Route.sample.id))
        }
    }
}
