//
//  HapticBeacon.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation

@MainActor
protocol HapticBeacon: WandDelegate {
    var beacon: AudioPlayerIdentifier? { get }
    
    init(at: CLLocation)
    func start()
    func stop()
}
