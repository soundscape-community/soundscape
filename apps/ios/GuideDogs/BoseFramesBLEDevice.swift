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

class BoseFramesBLEDevice: BaseBLEDevice {

    private var boseSensorConfig: CBCharacteristic?
    private var boseSensorData: CBCharacteristic?
    private let eventProcessor: BoseSensorDataProcessor
    private var sensorConfig: BoseSensorConfiguration?
    private var isHeadtrackingStarted: Bool = false
    var headingUpdateDelegate: BoseHeadingUpdateDelegate?
    
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
    // Denna anropas från BLEManager när en enhet hittades
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
        
        config.rotationPeriod = 80
        let myData = config.toConfigToData()
        self.writeValueToConfig(value: myData)
        self.isHeadtrackingStarted = true
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
    internal override func initializationComplete() {
        GDLogBLEInfo("caught init complete. Leta upp Charateristics")
        for service in self.peripheral.services! {
            if (service.uuid.uuidString == "FDD2") {
                for c in service.characteristics! {
                    if c.uuid.uuidString == BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC.uuidString {
                        self.boseSensorConfig = c
//                        self.peripheral.setNotifyValue(true, for: self.boseSensorConfig!)
                        self.peripheral.readValue(for: c)
                        continue
                    }
                    if c.uuid.uuidString == BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC.uuidString {
                        self.boseSensorData = c
  //                      boseDevice.setNotifyValue(true, for: self.boseHeadTrackingData!)
                        //   boseDevice.readValue(for: self.boseHeadTrackingData!)
                        continue
                    }
                }
            }
        }
        super.initializationComplete()
    }
    
    internal override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value 
        else { return }
        
        switch characteristic.uuid {
        case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_CONFIG_CHARACTERISTIC:
            sensorConfig = BoseSensorConfiguration.parseValue(data: value)
        
        case BOSE_FRAMES_SERVICE_CONSTANTS.CBUUID_HEADTRACKING_DATA_CHARACTERISTIC:
            let heading = eventProcessor.processSensorData(eventData: value)
            if let h = heading, let delegate = headingUpdateDelegate {
                delegate.onHeadingUpdate(newHeading: h)
            }
            
        default:
            GDLogBLEInfo("Got updated value for an unexpected characteristic: \(characteristic.uuid.uuidString) = \(characteristic.value)")
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
