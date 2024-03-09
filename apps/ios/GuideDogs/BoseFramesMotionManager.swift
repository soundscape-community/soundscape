//
//  BoseFramesMotionManager.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-06.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import Combine


extension Notification.Name {
    static let boseFramesDeviceConnected = Notification.Name("GDABoseFramesConnected")
    static let boseFramesDeviceConnectionFailed = Notification.Name("GDABoseFramesConnectionFailed")
}
class BoseFramesMotionManager: NSObject {

    static let DEVICE_MODEL_NAME: String = GDLocalizationUnnecessary("Bose Frames (Rondo)")
        
    // MARK: Attributes
    private let queue: OperationQueue
    //    private var deviceConnectedHandler: DeviceCompletionHandler?
    private var bleBoseFrames: BoseFramesBLEDevice?
//    private var initializationSemaphore: DispatchSemaphore?
    private var connectionTimer: Timer?
    private let connectionTimeOutSeconds: Double = 30.0
    private(set) var status: CurrentValueSubject<HeadphoneMotionStatus, Never>
    
    // MARK: Device attributes
    let model = BoseFramesMotionManager.DEVICE_MODEL_NAME
    let type: DeviceType = .boseFramesRondo
    private(set) var isConnecting = false
    var isFirstConnection = true
    private let accuracy_calibration_required_threshold: Double = 12.0 // If accuracy is above this value, consider the device calibrating
    private var _calibrationState: DeviceCalibrationState = .needsCalibrating
    private var _calibrationOverridden: Bool = false
    private var _deviceDelegate: DeviceDelegate?
    
    // MARK: UserHeadingProvider attributes
    private var _idDummy: UUID // Create a dummy Id for this device as it will not get its ID until connected, but Device requires a non-optional id
    private weak var _headingDelegate: UserHeadingProviderDelegate?
    var _accuracy = 10000.0 // Just a very high value... Will adjust when we start getting updates
    
    
    
    // MARK: Initializers
    override init() {
        self._idDummy = UUID()
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
        if let boseDevice = bleBoseFrames  {
            return boseDevice.state == .ready //return status.value == .calibrated || status.value == .connected // boseDevice.state == .ready
        }
        else {
            return false
        }
    }
    
    
    var name: String {
        if let dev = bleBoseFrames, let name = dev.name {
            return name
        } else {
            return ""
        }
    }
    
    /// Return the identifier for the peripheral. This value is valid only whenthe device is ready and will return a dummy UUID if called before init has finished
    var id: UUID {
        if let dev = bleBoseFrames {
            return dev.uuid
        } else {
            return _idDummy
        }
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
        device.isFirstConnection = true

        callback(.success(device))
        
        device.connect()
    }
    
    func connect() {
               
        guard bleBoseFrames == nil else {
            GDLogHeadphoneMotionInfo("Connecting Bose Frames, but they are already connected.")
            return
        }
        isConnecting = true
        
        AppContext.shared.bleManager.startScan(for: BoseFramesBLEDevice.self, delegate: self)
        
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeOutSeconds, repeats: false) {timer in
            self.queue.addOperation {
                GDLogHeadphoneMotionError("Bose: Connection timed out!")
                AppContext.shared.bleManager.stopScan()
                self.status.value = .disconnected
                self.isConnecting = false
                NotificationCenter.default.post(name: Notification.Name.boseFramesDeviceConnectionFailed, object: nil)
                self.connectionTimer?.invalidate()
                self.connectionTimer = nil
            }
        }
    }
    
    func disconnect() {
        GDLogHeadphoneMotionInfo("Disconnect called")
        connectionTimer?.invalidate()
        connectionTimer = nil
        isConnecting = false
        status.value = .disconnected
        stopUserHeadingUpdates()
        if(self._calibrationState == .calibrating) {
            NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationCancelled, object: nil)
        }
        deviceDelegate?.didDisconnectDevice(self)
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
            GDLogHeadphoneMotionError("Trying to start heading updates for Bose Frames, but the device is not ready")
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
        let previousCalibrationState = _calibrationState
        GDLogHeadphoneMotionVerbose("Got heading update: \(newHeading.value) : \(newHeading.accuracy!)")
        
        self._accuracy = Double(newHeading.accuracy!)
        if _accuracy < self.accuracy_calibration_required_threshold {
            if previousCalibrationState != .calibrated {
//                status.value = .calibrated
                _calibrationState = .calibrated
//                GDLogHeadphoneMotionInfo("Bose: Done calibrating!")
                NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationDidFinish, object: nil)
            }
        } else if previousCalibrationState != .calibrating {
//            status.value = .connected
            _calibrationState = .calibrating
            GDLogHeadphoneMotionInfo("Bose: Start calibrating!")
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
            } else {
                GDLogHeadphoneMotionInfo("Bose Frames state changed, but still not ready (\(device.state))")
            }
        }
    }
    
    func onDeviceNameChanged(_ device: BLEDevice, _ name: String) {
        // no-op
    }
    
    func onDevicesChanged(_ discovered: [BLEDevice]) {
        if bleBoseFrames == nil  {
            for i in 0..<discovered.count {
                if(discovered[i] is BoseFramesBLEDevice) {
                    self.bleBoseFrames = (discovered[i] as! BoseFramesBLEDevice)
                    bleBoseFrames?.deviceStateChangedDelegate = self
                    break
                }
            }
        }
    }
}

extension BoseFramesMotionManager: BoseStateChangeDelegate {
    func onBoseDeviceDisconnected() {
        GDLogHeadphoneMotionInfo("Bose was disconnected (StateChanged)")
        self.disconnect()
    }
    
    func onBoseDeviceReady() {
        GDLogHeadphoneMotionInfo("Config has been read by the BLE-device, we set to go!")

        connectionTimer?.invalidate()
        connectionTimer = nil
        isConnecting = false
        AppContext.shared.bleManager.stopScan()
        NotificationCenter.default.post(name: Notification.Name.boseFramesDeviceConnected, object: nil)
//        status.value = (_calibrationState == .calibrated ? .calibrated : .connected)
        isFirstConnection = false
    }
}
