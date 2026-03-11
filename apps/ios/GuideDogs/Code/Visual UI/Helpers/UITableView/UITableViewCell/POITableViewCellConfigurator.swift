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
    private var resolvedDetailsByKey: [String: LocationDetail] = [:]
    
    init(cellsAreButtons: Bool = true) {
        self.cellsAreButtons = cellsAreButtons
    }
    
    // MARK: `TableViewCellConfigurator`
    
    func configure(_ cell: TableViewCell, forDisplaying model: Model) {
        let configurationID = UUID()
        cell.asyncConfigurationID = configurationID
        cell.asyncConfigurationTask?.cancel()

        applyDefaultPresentation(to: cell, poi: model)
        configureSubtitle(cell, model: model)
        configureAccessibility(cell, poi: model, detail: resolvedDetailsByKey[model.key])
        
        if cellsAreButtons {
            cell.accessibilityTraits = .button
        }

        if let detail = resolvedDetailsByKey[model.key] {
            applyResolvedPresentation(detail, to: cell, poi: model)
            return
        }

        cell.asyncConfigurationTask = Task { @MainActor [weak self, weak cell] in
            guard let self, let cell else {
                return
            }

            let detail = await LocationDetail.load(entity: model)
            self.resolvedDetailsByKey[model.key] = detail

            guard cell.asyncConfigurationID == configurationID else {
                return
            }

            self.applyResolvedPresentation(detail, to: cell, poi: model)
        }
    }

    private func applyDefaultPresentation(to cell: POITableViewCell, poi: POI) {
        configureTitle(cell, poi: poi)
        configureDetail(cell, poi: poi)
        configureImageView(cell, poi: poi)
    }

    private func applyResolvedPresentation(_ detail: LocationDetail, to cell: POITableViewCell, poi: POI) {
        if detail.isMarker {
            configureTitle(cell, marker: detail, poi: poi)
            configureDetail(cell, marker: detail)
            configureImageView(cell, marker: detail)
        } else {
            applyDefaultPresentation(to: cell, poi: poi)
        }

        configureAccessibility(cell, poi: poi, detail: detail)
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
    
    private func configureAccessibility(_ cell: POITableViewCell, poi: Model, detail: LocationDetail?) {
        configureAccessibilityHint(cell, poi: poi)

        guard let detail, accessibilityActionDelegate != nil else {
            cell.accessibilityCustomActions = nil
            return
        }
        
        cell.accessibilityCustomActions = LocationAction.accessibilityCustomActions(for: detail, entity: poi) { [weak self] action, entity in
            self?.accessibilityActionDelegate?.didSelectLocationAction(action, entity: entity)
        }
    }
    
}
