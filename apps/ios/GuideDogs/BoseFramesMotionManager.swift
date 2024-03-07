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
    private var bleBoseFrames: BoseFramesBLEDevice?
    
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
    private weak var _headingDelegate: UserHeadingProviderDelegate?
    var _accuracy = 10000.0 // Just a very high value... Will adjust when we start getting updates

    
    
    // MARK: Initializers
    convenience init(id: UUID, name: String) {
        self.init()
        self._name = ""
        self._id = id
    }
    
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

        GDLogHeadphoneMotionInfo("FIXME: connect function NOT IMPLEMENTED")

        guard !self.isConnected else {
            GDLogHeadphoneMotionInfo("Connecting Bose Frames, but they are already connected.")
            return
        }
        
        AppContext.shared.bleManager.startScan(for: BoseFramesBLEDevice.self, delegate: self)
    }
    
    func disconnect() {
        GDLogHeadphoneMotionInfo("FIXME! Disconnect called, but has no way to diconnect!")
        stopUserHeadingUpdates()
    }
}

// MARK: UserHeadingProvider
extension BoseFramesMotionManager: UserHeadingProvider {
    var headingDelegate: UserHeadingProviderDelegate? {
        get {
            return self._headingDelegate
        }
        set (newDelegate) {
            self._headingDelegate = newDelegate
        }
    }
    
    var accuracy: Double {
        return self._accuracy
    }
    
    func startUserHeadingUpdates() {
        guard self.isConnected else {
            return
        }
        bleBoseFrames?.headingUpdateDelegate = self
        bleBoseFrames?.startHeadTracking()
        GDLogHeadphoneMotionInfo("FIXME: Start Bose sensor updates")
    }

    // TODO: Implement UserHeadingProvider.stopUserHeadingUpdates
    func stopUserHeadingUpdates() {
        guard self.isConnected else {
            return
        }
        bleBoseFrames?.headingUpdateDelegate = nil
        bleBoseFrames?.stopHeadTracking()
        GDLogHeadphoneMotionInfo("FIXME: Stop Bose sensor updates")
    }
}

extension BoseFramesMotionManager: BoseHeadingUpdateDelegate {
    func onHeadingUpdate(newHeading: HeadingValue!) {
        self._accuracy = Double(newHeading.accuracy!)
        self._calibrationState = (_accuracy < 5 ?  .calibrated : .calibrating )
        self._headingDelegate?.userHeadingProvider(self, didUpdateUserHeading: newHeading)
    }
}

extension BoseFramesMotionManager: BLEManagerScanDelegate {
    func onDeviceStateChanged(_ device: BLEDevice) {
        if(device.state != .ready) {
            GDLogHeadphoneMotionInfo("Bose Frames are not ready... Something perhaps needs to be done")
        }
    }
    
    func onDeviceNameChanged(_ device: BLEDevice, _ name: String) {
        self._name = name
    }
    
    func onDevicesChanged(_ discovered: [BLEDevice]) {
        for i in 0..<discovered.count {
            if(discovered[i] is BoseFramesBLEDevice) {
                self.bleBoseFrames = (discovered[i] as! BoseFramesBLEDevice)
                let device = self
                device.isConnected = true
                self.queue.addOperation {
                    if let callback = device.deviceConnectedHandler {
                        callback(.success(device))
                    }
                    device.startUserHeadingUpdates()
                }
                break
            }
        }
    }
}
