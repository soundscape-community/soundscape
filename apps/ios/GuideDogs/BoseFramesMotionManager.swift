//
//  BoseFramesMotionManager.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-06.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import Combine



class BoseFramesMotionManager: NSObject {
    
    static let DEVICE_MODEL_NAME: String = GDLocalizationUnnecessary("Bose Frames (Rondo)")
    
    // MARK: Attributes
    private let queue: OperationQueue
    //    private var deviceConnectedHandler: DeviceCompletionHandler?
    private var bleBoseFrames: BoseFramesBLEDevice?
    private var initializationSemaphore: DispatchSemaphore?
    private(set) var status: CurrentValueSubject<HeadphoneMotionStatus, Never>
    
    // MARK: Device attributes
    private var _name: String
    let model = BoseFramesMotionManager.DEVICE_MODEL_NAME
    let type: DeviceType = .boseFramesRondo
//    var isConnected = false
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
        status = .init(.disconnected)
        super.init()
    }
}



// MARK: CalibratableDevice
extension BoseFramesMotionManager: CalibratableDevice {
    var isConnected: Bool {
        guard let boseDevice = bleBoseFrames
        else {
            return false
        }
        
        return status.value == .calibrated || status.value == .connected // boseDevice.state == .ready
    }
    
    
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
        GDLogHeadphoneMotionInfo("Setting up new Bose device")
        let device = BoseFramesMotionManager()
        let semaphore = DispatchSemaphore(value: 0)
        device.initializationSemaphore = semaphore
        
        device.isFirstConnection = true
        //        device.deviceConnectedHandler = callback
        
        device.connect()
        device.status.value = .disconnected
        // I Think this is a pretty ugly way of making the initialization syncronous, but it must be done in sync...
        semaphore.wait()
   /*     callback(.success(device))
*/
        callback(.success(device))
/*        let result = semaphore.wait(timeout: .now() + 30)
        switch result {
        case .success:
            callback(.success(device))
        case .timedOut:
            callback(.failure(.failedConnection))
        }
  */
    }
    
    func connect() {
               
        guard bleBoseFrames == nil else {
            GDLogHeadphoneMotionInfo("Connecting Bose Frames, but they are already connected.")
            return
        }
        
        AppContext.shared.bleManager.startScan(for: BoseFramesBLEDevice.self, delegate: self)
    }
    
    func disconnect() {
        GDLogHeadphoneMotionInfo("FIXME! Disconnect called, but has no way to diconnect!")
        status.value = .disconnected
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
        guard let boseDevice = bleBoseFrames, boseDevice.state == .ready
        else {
            GDLogHeadphoneMotionError("Trying to start heading updates for Bose FRames, buit the device is not ready")
            return
        }
        status.value = (_calibrationState == .calibrated ? .calibrated : .connected)
        boseDevice.headingUpdateDelegate = self
        boseDevice.startHeadTracking()
    }
    
    // TODO: Implement UserHeadingProvider.stopUserHeadingUpdates
    func stopUserHeadingUpdates() {
        guard let boseDevice = bleBoseFrames, boseDevice.state == .ready
        else {
            GDLogHeadphoneMotionError("Trying to stop heading updates for Bose Frames, buit the device is not ready")
            return
        }
        status.value = .inactive
        boseDevice.headingUpdateDelegate = nil
        boseDevice.stopHeadTracking()
    }
}

extension BoseFramesMotionManager: BoseHeadingUpdateDelegate {
    func onHeadingUpdate(newHeading: HeadingValue!) {
//        let previousStatus = status
        let previousCalibrationState = _calibrationState
        GDLogHeadphoneMotionInfo("Got heading update: \(newHeading.value) : \(newHeading.accuracy!)")
        
        self._accuracy = Double(newHeading.accuracy!)
        if _accuracy < 5 {
            if previousCalibrationState != .calibrated {
                status.value = .calibrated
                _calibrationState = .calibrated
                NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationDidFinish, object: nil)
            }
        } else if previousCalibrationState != .calibrating {
            status.value = .connected
            _calibrationState = .calibrating
            NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationDidStart, object: nil)
        }

        if(_headingDelegate == nil){
            GDLogHeadphoneMotionError("MOT: No HeadingUpdateDelegate!!!")
        }
        
        self._headingDelegate?.userHeadingProvider(self, didUpdateUserHeading: newHeading)
    }
}

extension BoseFramesMotionManager: BLEManagerScanDelegate {
    
    func onDeviceStateChanged(_ device: BLEDevice) {
        if(device is BoseFramesBLEDevice) {
            if(device.state == .ready) {
                GDLogHeadphoneMotionInfo("Bose Frames are ready, starting to sample the sensor")
                let boseDevice = device as! BoseFramesBLEDevice
                AppContext.shared.bleManager.stopScan()
                boseDevice.headingUpdateDelegate = self
//                self.startUserHeadingUpdates()
            } else {
                GDLogHeadphoneMotionInfo("Bose Frames state changed, but still not ready (\(device.state))")
            }
        }
    }
    
    func onDeviceNameChanged(_ device: BLEDevice, _ name: String) {
        self._name = name
    }
    
    func onDevicesChanged(_ discovered: [BLEDevice]) {
        if bleBoseFrames == nil  {
            for i in 0..<discovered.count {
                if(discovered[i] is BoseFramesBLEDevice) {
                    self.bleBoseFrames = (discovered[i] as! BoseFramesBLEDevice)
                    bleBoseFrames?.initializationDelegate = self
                    break
                }
            }
        }
    }
}

extension BoseFramesMotionManager: BoseInitializationDoneDelegate {
    func onBoseConfigDidRead() {
        GDLogHeadphoneMotionInfo("Config has been read by the BLE-device, we set to go!")
        AppContext.shared.bleManager.stopScan()
        status.value = (_calibrationState == .calibrated ? .calibrated : .connected)
        
        // Need to start the sensor to calibrate?
        
        initializationSemaphore?.signal()
    }
}
