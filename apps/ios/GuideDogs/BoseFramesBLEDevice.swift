//
//  BoseHeadTrackerTest.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-05.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

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

protocol BoseHeadingUpdateDelegate {
    func onHeadingUpdate(newHeading: HeadingValue!)
}

enum BoseFramesState: String, Codable {
    case unknown
    case disconnected
    case discovered
    case connecting
    case connected
    case ready
}
class BoseFramesBLEDevice: BaseBLEDevice {
    private static let BOSE_HEADING_UPDATE_INTERVAL: UInt16 = 40 // Valid intervals in ms: 320, 160, 80, 40, 20,

    // MARK: BaseBLEDevice compliance
    private struct BoseSensorService: BLEDeviceService {
        static var uuid: CBUUID = BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE
        
        static var characteristicUUIDs: [CBUUID] = [
            BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC,
            BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC
        ]
    }
    override class var services: [BLEDeviceService.Type] {
        get {
            return [BoseSensorService.self]
        }
    }
  
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
  
    // MARK: Attributes
    private var boseCharacteristicSensorConfig: CBCharacteristic?
    private var sensorConfig: BoseSensorConfiguration?
   
    private var boseCharacteristicSensorData: CBCharacteristic?
    private let eventProcessor: BoseSensorDataProcessor
   
    private(set) var boseConnectionState: CurrentValueSubject<BoseFramesState, Never>
    private var isHeadtrackingStarted: Bool = false
    private(set) var isFirstConnection: Bool = true

    // MARK: Delegates
    var headingUpdateDelegate: BoseHeadingUpdateDelegate?
    var deviceStateChangedDelegate: BoseBLEStateChangeDelegate?
    
    
    
    
    // MARK: Init
    override init(peripheral: CBPeripheral, type deviceType: BLEDeviceType, delegate: BLEDeviceDelegate?) {
        eventProcessor = BoseSensorDataProcessor()
        boseConnectionState = .init(.unknown)
        super.init(peripheral: peripheral, type: deviceType, delegate: delegate)
    }
    
    required convenience init(peripheral: CBPeripheral, delegate: BLEDeviceDelegate?) {
        self.init(peripheral: peripheral, type: .headset, delegate: delegate)
    }
    
    
    // MARK: Controls for headtracking
    func startHeadTracking() {
        guard let config = sensorConfig, isHeadtrackingStarted == false
        else {
            GDLogBLEError("Bose: Attempted to start headtracking, but device is not ready")
            return
        }
        
        config.rotationPeriod = BoseFramesBLEDevice.BOSE_HEADING_UPDATE_INTERVAL

        self.writeValueToConfig(value: config.toConfigToData())
        self.isHeadtrackingStarted = true
/*
        let state: HeadsetConnectionEvent.State = isFirstConnection ? .firstConnection : .reconnected
        
        AppContext.process(HeadsetConnectionEvent(BoseFramesMotionManager.DEVICE_MODEL_NAME, state: state))
*/
        isFirstConnection = false
    }
    
    func stopHeadTracking() {
        guard let config = sensorConfig, isHeadtrackingStarted == true
        else {
            GDLogBLEError("Bose: Attempted to stop headtracking, but device is not ready")
            return
        }

        config.rotationPeriod = 0
        
        self.writeValueToConfig(value: config.toConfigToData())
        self.isHeadtrackingStarted = false
        
  //      AppContext.process(HeadsetConnectionEvent(BoseFramesMotionManager.DEVICE_MODEL_NAME, state: .disconnected))
    }
    
    func isHeadTrackingStarted() -> Bool {
        return self.isHeadtrackingStarted
    }
    
    internal func writeValueToConfig(value: Data){
        let device = super.peripheral
        guard
            let configCharacteristic = boseCharacteristicSensorConfig
        else {
            GDLogBLEError("Bose: Trying to write to config, but something failed...")
            return
        }
        
        if(self.state != .ready) {
            GDLogBLEError("Bose: Trying to write to config, but state != ready. Trying anyway")
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
        GDLogBLEInfo("Bose: Connection to Bose Frames has completed. Will initialize before ready")
        
        for service in self.peripheral.services! {
            if (service.uuid == BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_SERVICE) {
                for c in service.characteristics! {
                    switch c.uuid {
                    case  BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC:
                        GDLogBLEInfo("Found Bose Config Characteristic")
                        self.boseCharacteristicSensorConfig = c
                        self.peripheral.readValue(for: c)
                        
                    case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC:
                        GDLogBLEInfo("Found Bose Data Characteristic")
                        self.boseCharacteristicSensorData = c
                        self.peripheral.setNotifyValue(true, for: c)
                        continue

                    default:
                        () // Noop
                    }
                }
            }
        }
        if boseCharacteristicSensorData != nil && boseCharacteristicSensorConfig != nil {
            boseConnectionState.value = .connected
        }
    }
    
    internal override func onDidDisconnect(_ peripheral: CBPeripheral) {
//        let wasReady: Bool = (state == .ready)
        super.onDidDisconnect(peripheral)
        
        boseConnectionState.value = .disconnected
        deviceStateChangedDelegate?.onBoseDeviceDisconnected()

        GDLogBLEInfo("Bose: didDisconnect")
    }
    
    internal override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        guard let value = characteristic.value
        else { return }
        
        switch characteristic.uuid {
        case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC:
            GDLogBLEInfo("Bose: Read sensor config")
            sensorConfig = BoseSensorConfiguration.parseValue(data: value)
            boseConnectionState.value = .ready
            
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
        switch boseConnectionState.value {

        case .discovered, .unknown:
            AppContext.shared.bleManager.connect(self)
            boseConnectionState.value = .connecting

        default:
            GDLogBLEInfo("Received an onWasDiscovered, but device has already been discovered. Ignoring...")
        }
    }
}



