//
//  POITableViewCellConfigurator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSLanguage

@MainActor
class POITableViewCellConfigurator: TableViewCellConfigurator {
    
    typealias TableViewCell = POITableViewCell
    typealias Model = POI
    
    // MARK: Properties
    
    var location: CLLocation?
    weak var accessibilityActionDelegate: LocationAccessibilityActionDelegate?
    let cellsAreButtons: Bool
    
    init(cellsAreButtons: Bool = true) {
        self.cellsAreButtons = cellsAreButtons
    }
    
    // MARK: `TableViewCellConfigurator`
    
    func configure(_ cell: TableViewCell, forDisplaying model: Model) {
        let detail = LocationDetail(entity: model)

        if detail.isMarker {
            configureTitle(cell, marker: detail, poi: model)
            configureDetail(cell, marker: detail)
            configureImageView(cell, marker: detail)
        } else {
            configureTitle(cell, poi: model)
            configureDetail(cell, poi: model)
            configureImageView(cell, poi: model)
        }
        
        configureSubtitle(cell, model: model)
        configureAccessibilityHint(cell, poi: model)
        configureAccessibilityCustomActions(cell, poi: model)
        
        if cellsAreButtons {
            cell.accessibilityTraits = .button
        }
    }
    
    private func configureTitle(_ cell: POITableViewCell, poi: POI) {
        cell.titleLabel.text = poi.localizedName
        cell.titleLabel.accessibilityLabel = poi.localizedName
    }
    
    private func configureTitle(_ cell: POITableViewCell, marker: LocationDetail, poi: POI) {
        let name = marker.displayName
        
        cell.titleLabel.text = name
        
        if poi is Address, marker.nickname == nil {
            cell.titleLabel.accessibilityLabel = GDLocalizedString("markers.generic_name")
        } else {
            cell.titleLabel.accessibilityLabel = GDLocalizedString("markers.marker_with_name", name)
        }
    }
    
    private func configureDetail(_ cell: POITableViewCell, poi: POI) {
        cell.detailLabel.text = poi.addressLine
    }
    
    private func configureDetail(_ cell: POITableViewCell, marker: LocationDetail) {
        cell.detailLabel.text = marker.displayAddress
    }
    
    private func configureSubtitle(_ cell: POITableViewCell, model: Model) {
        // Initialize `distance` and `direction` to
        // an invalid value
        var distance = -1.0
        var direction = -1.0
        
        if let userLocation = location {
            distance = model.distanceToClosestLocation(from: userLocation)
            direction = model.bearingToClosestLocation(from: userLocation)
        }
        
        var text: String?
        var accessibilityLabel: String?
        
        if distance > 0, direction.isValid {
            let cardinalDirection = CardinalDirection(direction: direction)!
            
            // "30 m・NW"
            text = LanguageFormatter.string(from: distance, abbreviated: true) + "・" + cardinalDirection.localizedAbbreviatedString
            // "30 meters・North West"
            accessibilityLabel = LanguageFormatter.spellOutDistance(distance) + cardinalDirection.localizedString
        } else if distance >= 0 {
            // "30 m"
            text = LanguageFormatter.string(from: distance, abbreviated: true)
            // "30 meters"
            accessibilityLabel = LanguageFormatter.spellOutDistance(distance)
        } else if direction.isValid {
            let cardinalDirection = CardinalDirection(direction: direction)!
            
            // "NW"
            text = cardinalDirection.localizedAbbreviatedString
            // "North West"
            accessibilityLabel = cardinalDirection.localizedString
        }
        
        cell.subtitleLabel.text = text
        cell.subtitleLabel.accessibilityLabel = accessibilityLabel
    }
    
    private func configureImageView(_ cell: POITableViewCell, poi: POI) {
        cell.imageViewType = .place
    }
    
    private func configureImageView(_ cell: POITableViewCell, marker _: LocationDetail) {
        cell.imageViewType = .marker
    }
    
    private func configureAccessibilityHint(_ cell: POITableViewCell, poi: Model) {
        // Use the default accessibility label and hint
        cell.accessibilityLabel = nil
        cell.accessibilityHint = GDLocalizedString("location.select.hint")
    }
    
    private func configureAccessibilityCustomActions(_ cell: POITableViewCell, poi: Model) {
        guard accessibilityActionDelegate != nil else {
            return
        }
        
        cell.accessibilityCustomActions = LocationAction.accessibilityCustomActions(for: poi) { [weak self] action, entity in
            self?.accessibilityActionDelegate?.didSelectLocationAction(action, entity: entity)
        }
    }
    
}
