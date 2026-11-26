//
//  HapticBeacon.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import CoreLocation

protocol HapticBeacon: WandDelegate {
    var beacon: PlaybackHandle? { get }
    
    init(at: CLLocation)
    func start()
    func stop()
}
