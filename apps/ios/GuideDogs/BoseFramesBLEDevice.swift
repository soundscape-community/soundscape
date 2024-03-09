//
//  BoseHeadTrackerTest.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-05.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth

struct BOSE_FRAMES_SERVICE_CONSTANTS {
    static let CBUUID_HEADTRACKING_SERVICE: CBUUID = CBUUID(string: "FDD2")
    static let CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC: CBUUID = CBUUID(string: "5AF38AF6-000E-404B-9B46-07F77580890B")
    static let CBUUID_HEADTRACKING_DATA_CHARACTERISTIC: CBUUID = CBUUID(string: "56A72AB8-4988-4CC8-A752-FBD1D54A953D")
    static let CBUUID_HEADTRACKING_INFO_CHARACTERISTIC: CBUUID = CBUUID(string: "855CB3E7-98FF-42A6-80FC-40B32A2221C1")
}
protocol BoseBLEStateChangeDelegate {
    func onBoseDeviceReady()
    func onBoseDeviceDisconnected()
}
private enum BoseFramesState: String, Codable {
    case unknown
    case discovered
    case connecting
    case connected
    case ready
}
class BoseFramesBLEDevice: BaseBLEDevice {
    private let bose_heading_update_interval: UInt16 = 40 // Valid intervals in ms: 320, 160, 80, 40, 20,
    private var boseSensorConfig: CBCharacteristic?
    private var boseSensorData: CBCharacteristic?
    private let eventProcessor: BoseSensorDataProcessor
    private var sensorConfig: BoseSensorConfiguration?
    private var isHeadtrackingStarted: Bool = false
    private var boseConnectionState: BoseFramesState = .unknown
    private var isFirstConnection: Bool = true
    var name: String? {
        get {            
            return self.peripheral.name
        }
    }
    var uuid: UUID {
        get {
            return self.peripheral.identifier
        }
    }
    
    var headingUpdateDelegate: BoseHeadingUpdateDelegate?
    var deviceStateChangedDelegate: BoseBLEStateChangeDelegate?
    
    override class var services: [BLEDeviceService.Type] {
        get {
            return [BoseSensorService.self]
        }
    }
    
    // MARK: Init
    override init(peripheral: CBPeripheral, type deviceType: BLEDeviceType, delegate: BLEDeviceDelegate?) {
        eventProcessor = BoseSensorDataProcessor()
        super.init(peripheral: peripheral, type: deviceType, delegate: delegate)
    }
    
    required convenience init(peripheral: CBPeripheral, delegate: BLEDeviceDelegate?) {
        self.init(peripheral: peripheral, type: .headset, delegate: delegate)
    }
    
    
    // MARK: Controls for headtracking
    func startHeadTracking() {
        guard let config = sensorConfig
        else {
            GDLogBLEError("Cannot start headtracking. Bose headphones are not ready (missing config)")
            return
        }
        
        config.rotationPeriod = bose_heading_update_interval
        let myData = config.toConfigToData()
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = true
        let state: HeadsetConnectionEvent.State = isFirstConnection ? .firstConnection : .reconnected
        AppContext.process(HeadsetConnectionEvent(BoseFramesMotionManager.DEVICE_MODEL_NAME, state: state))
        isFirstConnection = false
    }
    
    func stopHeadTracking() {
        guard let config = sensorConfig
        else {
            GDLogBLEError("Cannot STOP headtracking. Bose headphones are not ready")
            return
        }

        config.rotationPeriod = 0
        let myData = config.toConfigToData()
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = false
        AppContext.process(HeadsetConnectionEvent(BoseFramesMotionManager.DEVICE_MODEL_NAME, state: .disconnected))
    }
    

    func isHeadTrackingStarted() -> Bool {
        return self.isHeadtrackingStarted
    }
    
    internal func writeValueToConfig(value: Data){
        let device = super.peripheral
        guard
            let configCharacteristic = boseSensorConfig
        else {
            GDLogBLEError("EARS: Trying to write to config, but something failed...")
            return
        }
        
        if(self.state != .ready) {
            GDLogBLEError("EARS: Trying to write to config, but state != ready. Trying anyway")
        }
        device.writeValue(value, for: configCharacteristic, type: .withResponse)
    }
    
    // MARK: Internal stuff
   /* override internal func onDidConnect(_ peripheral: CBPeripheral) {
        super.onDidConnect(peripheral)
        GDLogBLEInfo("Bose didConnect")
    }*/
    
    internal override func onConnectionComplete() {
        super.onConnectionComplete()
        GDLogBLEInfo("Connection to Bose Frames has completed.")
        boseConnectionState = .connected
        
        for service in self.peripheral.services! {
            if (service.uuid.uuidString == "FDD2") {
                for c in service.characteristics! {
                    if c.uuid.uuidString == BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC.uuidString {
                        GDLogBLEInfo("Found Bose Config Characteristic")
                        self.boseSensorConfig = c
                        self.peripheral.readValue(for: c)
                        continue
                    }
                    if c.uuid.uuidString == BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC.uuidString {
                        GDLogBLEInfo("Found Bose Data Characteristic")
                        self.boseSensorData = c
                        self.peripheral.setNotifyValue(true, for: c)
                        //   boseDevice.readValue(for: self.boseHeadTrackingData!)
                        continue
                    }
                }
            }
        }
    }
    internal override func onDidDisconnect(_ peripheral: CBPeripheral) {
        let wasReady: Bool = (state == .ready)
        super.onDidDisconnect(peripheral)

        if (wasReady){
            GDLogBLEInfo("Bose was disconnected, notifying of state change")
            deviceStateChangedDelegate?.onBoseDeviceDisconnected()
            AppContext.process(HeadsetConnectionEvent(BoseFramesMotionManager.DEVICE_MODEL_NAME, state: .disconnected))
        } else {
            GDLogBLEInfo("Bose was disconnected but wasn't ready so skipping notification")
        }
    }
    
    internal override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        guard let value = characteristic.value
        else { return }
        
        switch characteristic.uuid {
        case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC:
            GDLogBLEInfo("Read Bose sensor config")
            sensorConfig = BoseSensorConfiguration.parseValue(data: value)
            boseConnectionState = .ready
            deviceStateChangedDelegate?.onBoseDeviceReady()
            
        case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC:
            let heading = eventProcessor.processSensorData(eventData: value)
            if let h = heading, let delegate = headingUpdateDelegate {
                delegate.onHeadingUpdate(newHeading: h)
            } else {
                GDLogBLEInfo("ERROR: No heading update delegate!")
            }
            
        default:
            GDLogBLEVerbose("Got updated value for an unexpected characteristic: \(characteristic.uuid.uuidString) = \(characteristic.value)")
        }
    }
    
    internal override func onWasDiscovered(_ peripheral: CBPeripheral, advertisementData: [String : Any]) {
        super.onWasDiscovered(peripheral, advertisementData: advertisementData)
        switch boseConnectionState {
        case .discovered, .unknown:
            AppContext.shared.bleManager.connect(self)
            boseConnectionState = .connecting
        case .connected, .connecting, .ready:
            GDLogBLEInfo("Received an onWasDiscovered, but device has already been discovered. Ignoring...")
        }
    }
}

fileprivate struct BoseSensorService: BLEDeviceService {
    static var uuid: CBUUID = CBUUID(string: "FDD2")
    
    static var characteristicUUIDs: [CBUUID] = [
        BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC,
        BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC
    ]
}

protocol BoseHeadingUpdateDelegate {
    func onHeadingUpdate(newHeading: HeadingValue!)
}
