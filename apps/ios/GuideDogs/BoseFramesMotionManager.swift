//
//  BoseFramesMotionManager.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-06.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
class BoseFramesMotionManager: NSObject {

    static let DEVICE_MODEL_NAME: String = GDLocalizationUnnecessary("Bose Frames (rondo)")

    // MARK: Attributes
    private let queue: OperationQueue
    private var deviceConnectedHandler: DeviceCompletionHandler?

    // MARK: Device attributes
    private var _name: String
    let model = BoseFramesMotionManager.DEVICE_MODEL_NAME
    let type: DeviceType = .boseFramesRondo
    var isConnected = false
    var isFirstConnection = false
    private var _calibrationState: DeviceCalibrationState = .needsCalibrating
    private var _calibrationOverridden: Bool = false
    private var _deviceDelegate: DeviceDelegate?
    
    // MARK: UserHeadingProvider attributes
    private var _id: UUID
    weak var headingDelegate: UserHeadingProviderDelegate?
    var _accuracy = 10000.0 // Just a very high value... Will adjust when we start getting updates

    
    
    // MARK: Initializers
    override init() {

        self._name = ""
        self._id = UUID()
        queue = OperationQueue()
        queue.name = "BoseMotionUpdatesQueue"
        queue.qualityOfService = .userInteractive
        super.init()
        // TODO: Setup BoseBLEDevice and set delegates etc...

    }
}

// MARK: CalibratableDevice
extension BoseFramesMotionManager: CalibratableDevice {
    var name: String {
        return self._name
    }
    
    var id: UUID {
        return self._id
    }
    
    var calibrationState: DeviceCalibrationState {
        return self._calibrationState
    }
    
    var calibrationOverriden: Bool {
        get {
            return self._calibrationOverridden
        }
        set (newValue) {
            self._calibrationOverridden = newValue
        }
    }
    
    var deviceDelegate: DeviceDelegate? {
        get {
            return self._deviceDelegate
        }
        set (newDelegate) {
            self._deviceDelegate = newDelegate
        }
    }
    

    static func setupDevice(callback: @escaping DeviceCompletionHandler) {
        let device = BoseFramesMotionManager()
        device.isConnected = false
        device.isFirstConnection = true
        device.deviceConnectedHandler = callback
        device.connect()
    }

    func connect() {
        /*
         TODO:
         - If UUID != nil
         - Scan for BLE-device
         - Set some status (disconnected -> connecting -> connected)?
         - Discover services and characteristics
         - status = connecting
         - Start rotation sensor
         - status = connected
         */
        GDLogHeadphoneMotionInfo("FIXME: connect function NOT IMPLEMENTED")

        if let handler = self.deviceConnectedHandler {
          handler(.success(self))
        }
    }
    
    func disconnect() {
        GDLogHeadphoneMotionInfo("FIXME: disconnect function NOT IMPLEMENTED")
        // TODO: Stop motion updates. Call BLEManager to disconnect
    }
    
}

// MARK: UserHeadingProvider
extension BoseFramesMotionManager: UserHeadingProvider {
    var accuracy: Double {
        return self._accuracy
    }
    
    func startUserHeadingUpdates() {
        guard self.isConnected else {
            return
        }
        GDLogHeadphoneMotionInfo("FIXME: Start Bose sensor updates")
    }
    
    func stopUserHeadingUpdates() {
        guard self.isConnected else {
            return
        }
        GDLogHeadphoneMotionInfo("FIXME: Stop Bose sensor updates")
    }
}
