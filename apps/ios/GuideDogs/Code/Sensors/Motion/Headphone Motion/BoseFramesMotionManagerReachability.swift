//
//  BoseFramesReachability.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-06.
//  Copyright © 2024 Soundscape community. 
//  Licensed under the MIT License.
//

import Foundation
class BoseFramesMotionManagerReachability: DeviceReachability {
    /*
        private var boseBleDevice: BoseFramesBLEDevice? {
        get {
            return boseStateDelegate?.boseDevice
        }
    }
    */
    
    private var timer: Timer?
    private var completionHandler: ReachabilityCompletion?
    private let lock = NSLock()
    private var isActive: Bool = false
//    private var boseStateDelegate: BoseBLEStateChangeDelegate?
    
    init(){
        GDLogHeadphoneMotionInfo("[PING] BoseMotionReachability created")
  //      boseStateDelegate = BoseDeviceStateDelegate(livePingHandler: self.cleanup)
    }
    /// Dummy implementation.
    /// Redesign needed: Cannot use BLEManager as it cancells an ongoing discovery. Perhaps use coreBluetooth to see if headset is reachable?
    func ping(timeoutInterval: TimeInterval, completion: @escaping ReachabilityCompletion) {
        GDLogHeadphoneMotionInfo("Bose: [PING] returning dummy ping value...")
        return completion(true)
    }
    
    private func cleanup(isReachable: Bool) {
        self.lock.lock()
        
        defer {
            self.lock.unlock()
        }
        
        GDLogHeadphoneMotionInfo("[PING] Stopping Bose motion updates...")
        
        // Stop and reset timer
        timer?.invalidate()
        timer = nil
        
//        boseStateDelegate = nil
        
        GDLogHeadphoneMotionInfo("[PING] Bose reachability: \(isReachable)")
        // Return reachability and reset
        completionHandler?(isReachable)
        completionHandler = nil
        
        // Update state
        isActive = false
    }
    
}
