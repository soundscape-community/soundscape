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

import Foundation

enum BoseFramesMotionManagerStatus: Int, Equatable, Comparable {
    /// unknown: Status unknown. Inital state before attampting any connection. `bleBoseFrames` is probably nil
    case unknown
    /// disconnect: bleBoseFrames has been created but has yet to start connecting, or the device has been disconnected
    case disconnected
    /// connecting: Connection (pairing) with the device has started. `bleBoseFrames` may still be nil
    case connecting
    /// connected: Connection has completed. The device is now in the process of discovering services and configuring the device. Not yet ready, startUserHeadingUpdates will fail
    case connected
    /// ready: The device is ready to use
    case ready

    static func < (lhs: BoseFramesMotionManagerStatus, rhs: BoseFramesMotionManagerStatus) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class BoseFramesMotionManager: NSObject {

    static let DEVICE_MODEL_NAME: String = GDLocalizationUnnecessary("Bose Frames (Rondo)")
        
    // MARK: Attributes
    private let queue: OperationQueue
    private var bleBoseFrames: BoseFramesBLEDevice?
    private var bleBoseStatusUpdateSubscriber: AnyCancellable?
    private var connectionTimer: Timer?
    private let connectionTimeOutSeconds: Double = 30.0
    
    private(set) var status: CurrentValueSubject<BoseFramesMotionManagerStatus, Never>
    
    // MARK: Device attributes
    let model = BoseFramesMotionManager.DEVICE_MODEL_NAME
    let type: DeviceType = .boseFramesRondo
//    private(set) var isConnecting = false
    var isFirstConnection: Bool {
        get {
            guard let dev = bleBoseFrames else {return true}
            return dev.isFirstConnection
        }
    }
    
    // MARK: CalibratableDevice
    private let accuracy_calibration_required_threshold: Double = 12.0 // If accuracy is above this value, consider the device calibrating
    private var _calibrationState: DeviceCalibrationState
    private var _calibrationOverridden: Bool
    
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
        status = .init(.unknown)
        
        _calibrationState = .needsCalibrating
        _calibrationOverridden = false
        
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
        GDLogHeadphoneMotionInfo("Bose: SetupDevice")
        let device = BoseFramesMotionManager()

        callback(.success(device))
        
        device.connect()
    }
    
    func connect() {
               
        guard bleBoseFrames == nil else {
            GDLogHeadphoneMotionInfo("Bose: Connecting Bose Frames, but they are already connected.")
            return
        }
        
        AppContext.shared.bleManager.startScan(for: BoseFramesBLEDevice.self, delegate: self)
        status.value = .connecting
        
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeOutSeconds, repeats: false) {timer in
            self.queue.addOperation {
                GDLogHeadphoneMotionError("Bose: Connection timed out!")

                self.connectionTimer?.invalidate()
                self.connectionTimer = nil

                AppContext.shared.bleManager.stopScan()
                self.status.value = .disconnected

                NotificationCenter.default.post(name: Notification.Name.boseFramesDeviceConnectionFailed, object: nil)
            }
        }
    }
    
    func disconnect() {
        GDLogHeadphoneMotionInfo("Bose: Disconnect called")
        connectionTimer?.invalidate()
        connectionTimer = nil
    
        status.value = .disconnected
        stopUserHeadingUpdates()
        if (self._calibrationState == .calibrating) {
            NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationCancelled, object: nil)
        }
        bleBoseFrames = nil
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
            GDLogHeadphoneMotionError("Bose: Attemped to start heading updates, but the device was not ready")
            return
        }
        
       // status.value = (_calibrationState == .calibrated ? .calibrated : .connected)
        boseDevice.headingUpdateDelegate = self
        boseDevice.startHeadTracking()
    }
    
    // TODO: Implement UserHeadingProvider.stopUserHeadingUpdates
    func stopUserHeadingUpdates() {
        guard let boseDevice = bleBoseFrames, boseDevice.state == .ready
        else {
            GDLogHeadphoneMotionError("Bose: Attempted to stop heading updates, but the device was not ready")
            return
        }
//        status.value = .inactive
        boseDevice.headingUpdateDelegate = nil
        boseDevice.stopHeadTracking()
    }
}

extension BoseFramesMotionManager: BoseHeadingUpdateDelegate {

    func onHeadingUpdate(newHeading: HeadingValue!) {
        var accuracyRingQueue = [Double](repeating: 100.0, count: 10) // Collect 10 latest values for averaging accuracy
        var ringQueuePosition: Int = 0
        
        let previousCalibrationState = _calibrationState

        GDLogHeadphoneMotionVerbose("Bose: Got heading update: \(newHeading.value) : \(newHeading.accuracy!)")
        
        // Calculate a rolling average of accuracy to avoid jitters in the UI
        self._accuracy = Double(newHeading.accuracy!)
        accuracyRingQueue[ringQueuePosition] = _accuracy
        ringQueuePosition = (ringQueuePosition + 1) % 10
        var averageAccuracy = accuracyRingQueue.mean()!
        
        if averageAccuracy < self.accuracy_calibration_required_threshold {
            if previousCalibrationState != .calibrated {
                GDLogHeadphoneMotionInfo("Bose: Done calibrating!")
                _calibrationState = .calibrated
                NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationDidFinish, object: nil)
            }
            
        } else if previousCalibrationState != .calibrating {
            GDLogHeadphoneMotionInfo("Bose: Start calibrating!")
            _calibrationState = .calibrating
            NotificationCenter.default.post(name: Notification.Name.ARHeadsetCalibrationDidStart, object: nil)
        }

        if(_headingDelegate == nil){
            GDLogHeadphoneMotionError("Bose: No HeadingUpdateDelegate!!!")
        }
        OperationQueue.main.addOperation { [weak self] in
            guard let `self` = self else {
                return
            }
            self._headingDelegate?.userHeadingProvider(self, didUpdateUserHeading: newHeading)
        }
    }
}

extension BoseFramesMotionManager: BLEManagerScanDelegate {
    
    internal func onDeviceStateChanged(_ device: BLEDevice) {
        /// State change is monitored on the `BoseFramesBLEDevice.boseState` variable
    }
    
    internal func onDeviceNameChanged(_ device: BLEDevice, _ name: String) {
        // no-op
    }
    /// Called when bleManager has discovered devices.
    internal func onDevicesChanged(_ discovered: [BLEDevice]) {
        
        guard bleBoseFrames == nil else {return}
        
        for i in 0..<discovered.count {
            if let device  = discovered[i] as? BoseFramesBLEDevice {
                AppContext.shared.bleManager.stopScan()
                self.bleBoseFrames = device
                device.deviceStateChangedDelegate = self
                self.status.value = .disconnected
                            
                bleBoseStatusUpdateSubscriber = device.boseConnectionState
                    .receive(on: RunLoop.main)
                    .sink(receiveValue: { [weak self] (newValue) in
                        guard let `self` = self else {
                            return
                        }
                        switch newValue {
                        case .unknown:
                            GDLogHeadphoneMotionInfo("Bose: Device is unknown")
                            self.status.value = .unknown
                            
                        case .disconnected, .discovered:
                            GDLogHeadphoneMotionInfo("Bose: Device is \(newValue)")
                            self.status.value = .disconnected

                        case .connecting:
                            GDLogHeadphoneMotionInfo("Bose: Device is connecting")
                            self.status.value = .connecting

                        case .connected:
                            GDLogHeadphoneMotionInfo("Bose: Device is connected")
                            self.status.value = .connected

                        case .ready:
                            GDLogHeadphoneMotionInfo("Bose: Device is ready")
                            self.status.value = .ready
                      }
                    })
                break
            }
        }
    }
}

extension BoseFramesMotionManager: BoseBLEStateChangeDelegate {
    func onBoseDeviceDisconnected() {
        GDLogHeadphoneMotionInfo("Bose: Device was disconnected (StateChanged)")
        self.disconnect()
    }
    
    func onBoseDeviceReady() {
        GDLogHeadphoneMotionInfo("Bose: Config has been read by the BLE-device, we're set to go!")

        connectionTimer?.invalidate()
        connectionTimer = nil
        AppContext.shared.bleManager.stopScan()
        NotificationCenter.default.post(name: Notification.Name.boseFramesDeviceConnected, object: nil)
    }
}
