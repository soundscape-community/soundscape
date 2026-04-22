//
//  DynamicAudioEngineAsset.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

enum AssetSelectorInput {
    case heading(CLLocationDirection?, CLLocationDirection)
    case location(CLLocation?, CLLocation)
}

/// `DynamicAudioEngineAsset`s are distinct from standard `AudioEngineAsset`s in several
/// ways. They represent a set of audio components that together represent a single
/// continuous experience during which one of the components is always playing (i.e. think
/// audio beacon). Implementations of `DynamicAudioEngineAsset` must provide a "selector"
/// block that is responsible for choosing which asset should be playing at any given time.
/// The selector block can return `nil` allowing for the dynamic asset design to include
/// silence. Each audio component should be the same length (i.e. have the same number
/// of frames) and the implementation should indicate how many beats there are in the musical
/// phrase the components compose - this allows for intelligently switching between assets on
/// the beat.
protocol DynamicAudioEngineAsset: AudioEngineAsset, CaseIterable, Hashable {
    typealias Volume = Float
    
    /// A block which takes a user heading and a bearing to a POI and returns the case for the
    /// asset that should be playing and the volume the player should be playing at.
    typealias AssetSelector = (AssetSelectorInput) -> (asset: AllCases.Element, volume: Volume)?
    
    static var selector: AssetSelector? { get }
    
    static var beatsInPhrase: Int { get }
}

extension DynamicAudioEngineAsset {
    static var description: String {
        return String(describing: self)
    }
    
    /// Returns an appropriate default asset selector based on the number of asset in
    /// the dynamic audio engine asset (defined for asset counts of 2, 3, and 4).
    ///
    /// - Returns: An asset selector
    static func defaultSelector() -> AssetSelector? {
        switch allCases.count {
        case 2: return standardTwoRegionSelector()
        case 3: return standardThreeRegionSelector()
        case 4: return standardFourRegionSelector()
        default: return nil
        }
    }
    
    /// A default beacon asset selector for two regions (On Axis, Off Axis)
    ///
    /// The regions are defined dynamically based on `beaconRingingAngle`:
    ///  * On Axis: Central cone around POI direction,
    ///    `(angle >= 360 - threshold || angle <= threshold)`
    ///  * Off Axis: Remaining angular space
    ///
    /// - Note: `threshold` is configurable via SettingsContext and defines
    ///         how precise the user must be to hear the "on-axis" sound.
    ///
    /// - Returns: An asset selector
    static func standardTwoRegionSelector() -> AssetSelector? {
        guard allCases.count == 2 else {
            return nil
        }
        
        let assets = Array(allCases)
        
        return { input in
            if case .heading(let userHeading, let poiBearing) = input {
                guard let userHeading = userHeading else {
                    return (assets[1], 1.0)
                }
                
                let angle = userHeading.add(degrees: -poiBearing)
                
                // Configurable angle (in degrees) defining the width of the forward (on-axis) region.
                let threshold = SettingsContext.shared.beaconRingingAngle
                
                if angle >= (360.0 - threshold) || angle <= threshold {
                    return (assets[0], 1.0)
                } else {
                    return (assets[1], 1.0)
                }
            }
            return nil
        }
    }
    
    /// A default beacon asset selector for three regions (A+, A, Behind)
    ///
    /// The regions are defined dynamically using `beaconRingingAngle`:
    ///  * A+ (On Axis): Central cone,
    ///    `(angle >= 360 - threshold || angle <= threshold)`
    ///
    ///  * A (Near Axis): Side regions expanding from A+,
    ///    `(angle >= 235 && angle <= 360 - threshold) || (angle >= threshold && angle <= 125)`
    ///
    ///  * Behind: Remaining angular space,
    ///    `(angle > 125 && angle < 235)`
    ///
    /// - Note: Increasing `threshold` widens the A+ region and reduces precision.
    ///
    /// - Returns: An asset selector
    static func standardThreeRegionSelector() -> AssetSelector? {
        guard allCases.count == 3 else {
            return nil
        }
        
        let assets = Array(allCases)
        
        return { input in
            if case .heading(let userHeading, let poiBearing) = input {
                guard let userHeading = userHeading else { return (assets[2], 1.0) }
                let angle = userHeading.add(degrees: -poiBearing)
                
                // Configurable angle (in degrees) defining the width of the forward (on-axis) region.
                let threshold = SettingsContext.shared.beaconRingingAngle
                if angle >= (360.0 - threshold) || angle <= threshold {
                    return (assets[0], 1.0)
                } else if (angle >= 235 && angle <= (360.0 - threshold)) || (angle >= threshold && angle <= 125) {
                    return (assets[1], 1.0)
                } else {
                    return (assets[2], 1.0)
                }
            }
            return nil
        }
    }
    
    /// A default beacon asset selector for four regions (A+, A, B, Behind)
    ///
    /// The regions are defined dynamically using `beaconRingingAngle`:
    ///  * A+ (On Axis): Central cone,
    ///    `(angle >= 360 - threshold || angle <= threshold)`
    ///
    ///  * A: Narrow side regions near the forward direction,
    ///    `(angle >= 305 && angle <= 360 - threshold) || (angle >= threshold && angle <= 55)`
    ///
    ///  * B: Wider side regions,
    ///    `(angle >= 235 && angle <= 305) || (angle >= 55 && angle <= 125)`
    ///
    ///  * Behind: Remaining angular space,
    ///    `(angle > 125 && angle < 235)`
    ///
    /// - Note: `threshold` controls how wide the forward-facing region is.
    ///         Larger values make the beacon easier to trigger but less precise.
    ///
    /// - Returns: An asset selector
    static func standardFourRegionSelector() -> AssetSelector? {
        guard allCases.count == 4 else {
            return nil
        }
        
        let assets = Array(allCases)
        
        return { input in
            if case .heading(let userHeading, let poiBearing) = input {
                guard let userHeading = userHeading else { return (assets[3], 1.0) }
                let angle = userHeading.add(degrees: -poiBearing)
                
                // Configurable angle (in degrees) defining the width of the forward (on-axis) region.
                let threshold = SettingsContext.shared.beaconRingingAngle
                if angle >= (360.0 - threshold) || angle <= threshold {
                    return (assets[0], 1.0)
                } else if (angle >= 305 && angle <= (360.0 - threshold)) || (angle >= threshold && angle <= 55) {
                    return (assets[1], 1.0)
                } else if (angle >= 235 && angle <= 305) || (angle >= 55 && angle <= 125) {
                    return (assets[2], 1.0)
                } else {
                    return (assets[3], 1.0)
                }
            }
            
            return nil
        }
    }
}
