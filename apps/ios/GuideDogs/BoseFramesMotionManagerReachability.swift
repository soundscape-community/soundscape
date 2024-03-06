//
//  BoseFramesReachability.swift
//  Soundscape
//
//  Created by Niklas Mellegård on 2024-03-06.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import Foundation
class BoseFramesMotionManagerReachability: DeviceReachability {
    func ping(timeoutInterval: TimeInterval, completion: @escaping ReachabilityCompletion) {
        GDLogHeadphoneMotionInfo("FIXME: BoseMotionReachability.ping IS NOT IMPLEMENTED")
        completion(true)
    }
}
