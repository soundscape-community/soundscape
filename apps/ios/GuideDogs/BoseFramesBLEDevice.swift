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
    func onBoseDeviceStateChange(oldState: BLEDeviceState, newState: BLEDeviceState)
}

protocol BoseHeadingUpdateDelegate {
    func onHeadingUpdate(newHeading: HeadingValue!)
}

class BoseFramesBLEDevice: BaseBLEDevice {
    private static let BOSE_HEADING_UPDATE_INTERVAL: UInt16 = 40 // Valid intervals in ms: 320, 160, 80, 40, 20,

    // MARK: - BaseBLEDevice compliance
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
  
    // MARK: - Attributes
    private var boseCharacteristicSensorConfig: CBCharacteristic?
    private var sensorConfig: BoseSensorConfiguration?
   
    private var boseCharacteristicSensorData: CBCharacteristic?
    private let eventProcessor: BoseSensorDataProcessor
   
    private var isHeadtrackingStarted: Bool = false
    private(set) var isFirstConnection: Bool = true

    // MARK: Delegates
    var headingUpdateDelegate: BoseHeadingUpdateDelegate?
    var stateDidChangeDelegate: BoseBLEStateChangeDelegate?
    
    
    
    
    // MARK: - Init
    override init(peripheral: CBPeripheral, type deviceType: BLEDeviceType, delegate: BLEDeviceDelegate?) {
        eventProcessor = BoseSensorDataProcessor()
        super.init(peripheral: peripheral, type: deviceType, delegate: delegate)
    }
    
    required convenience init(peripheral: CBPeripheral, delegate: BLEDeviceDelegate?) {
        self.init(peripheral: peripheral, type: .headset, delegate: delegate)
    }
    
    
    // MARK: - Controls for headtracking
    func startHeadTracking() {
        guard let config = sensorConfig
        else {
            GDLogBLEError("Bose: Attempted to start headtracking, but device is not ready")
            return
        }
        guard isHeadtrackingStarted == false else {
            GDLogBLEInfo("Bose: Attempted to start headtracking, but headtracking is already started")
            return
        }
        
        config.rotationPeriod = BoseFramesBLEDevice.BOSE_HEADING_UPDATE_INTERVAL

        self.writeValueToConfig(value: config.toConfigToData())
        self.isHeadtrackingStarted = true
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
    
    // MARK: - BLE Device lifecycle
    /// The device has been discovered. BaseBLEDevice will set state to .discovered if it was .unknown
    internal override func onWasDiscovered(_ peripheral: CBPeripheral, advertisementData: [String : Any]) {
        let oldState = self.state

        super.onWasDiscovered(peripheral, advertisementData: advertisementData)
        let newState = self.state

        switch (oldState, newState) {
        case (.unknown, .disconnected):
            AppContext.shared.bleManager.connect(self)

        default:
            GDLogBLEInfo("Received an onWasDiscovered, but device did not transition from 'unknown to 'disconnected' perhaps already connecting? Current state: \(newState) (oldState: \(oldState))")
        }
        
        if oldState != newState {
            stateDidChangeDelegate?.onBoseDeviceStateChange(oldState: oldState, newState: newState)
        }
    }
    
    /// Peripheral was connected. BaseBLEDevice sets state to .initializing and starts to discover services
    override internal func onDidConnect(_ peripheral: CBPeripheral) {
        let oldState = self.state
        GDLogBLEInfo("Bose: onDidConnect")
        super.onDidConnect(peripheral)
        let newState = self.state
        
        if oldState != newState {
            stateDidChangeDelegate?.onBoseDeviceStateChange(oldState: oldState, newState: newState)
        }
    }
        
    /// Called from BaseBLE when services and characterstics have been discovered. BaseBLE does not change state.
    internal override func onSetupComplete() {
        GDLogBLEInfo("Bose: onSetupComplete")


        let oldState = self.state
        super.onSetupComplete()
        let newState = self.state
        
        if oldState != newState {
            stateDidChangeDelegate?.onBoseDeviceStateChange(oldState: oldState, newState: newState)
        }
    }
    
    ///  Caches relevant characteristics, requests currenct device configuration and subscribes to Heading updates
    ///  We will not call BaseBLEDevice.onConnectionComplete until we have read configuration
    internal override func onConnectionComplete() {
        
        GDLogBLEInfo("Bose: onConnectionComplete. Requesting current configuration")
        
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
        
        guard boseCharacteristicSensorData != nil && boseCharacteristicSensorConfig != nil else {
            GDLogBLEError("Bose: onConnectionComplete ERROR. Did not find both Config and Data Characteristic. This will not work...")
            return 
        }
        
        // Now, await response from the config charateristic and continue the flow in peripheral (_:didUpdateValue:_) when getting config data
    }
    
    private func onDidReadDeviceConfig(){
        GDLogBLEInfo("Bose: onDidReadConfig")

        // Only trigger state change if we are initializing...
        guard self.state == .initializing else {
            return
        }

        let oldState = self.state
        super.onConnectionComplete()
        let newState = self.state
        
        if oldState != newState {
            stateDidChangeDelegate?.onBoseDeviceStateChange(oldState: oldState, newState: newState)
        }
    }
    
    internal override func onWillDisconnect(_ peripheral: CBPeripheral) {
        GDLogBLEInfo("Bose: onWillDisconnect")
        let oldState = self.state
        super.onWillDisconnect(peripheral)
        let newState = self.state
        
        if oldState != newState {
            stateDidChangeDelegate?.onBoseDeviceStateChange(oldState: oldState, newState: newState)
        }
    }
    
    internal override func onDidDisconnect(_ peripheral: CBPeripheral) {
        let oldState = self.state
        super.onDidDisconnect(peripheral)
        let newState = self.state
        
        if oldState != newState {
            stateDidChangeDelegate?.onBoseDeviceStateChange(oldState: oldState, newState: newState)
        }
    }
    
    // MARK: Read value
    internal override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        
        guard let value = characteristic.value
        else { return }
        
        switch characteristic.uuid {
        case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC:
            GDLogBLEInfo("Bose: Read sensor config")
            sensorConfig = BoseSensorConfiguration.parseValue(data: value)

            self.onDidReadDeviceConfig()
            
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

        // BaseBLEDevice-implementation is a no-op
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)        
    }
}



