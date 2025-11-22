//
//  ContinuousAudioPlayer.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import AVFoundation

class ContinuousAudioPlayer: BaseAudioPlayer {
    
    private(set) var buffers: [AVAudioPCMBuffer] = []
    
    // Queue parameter removed (Phase 7 Step 2). Continuous sounds are generated synchronously
    // so they do not require the injected scheduling queue used by discrete/dynamic players.
    required init?(_ sound: SynchronouslyGeneratedSound) {
        super.init(sound: sound, queue: DispatchQueue.main)
    }
    
    override func prepare(engine: AVAudioEngine, completion: ((_ success: Bool) -> Void)?) {
        state = .preparing
        
        guard let sound = sound as? SynchronouslyGeneratedSound else {
            completion?(false)
            return
        }
        
        for index in 0 ..< layers.count {
            guard let buffer = sound.generateBuffer(forLayer: index) else {
                completion?(false)
                return
            }
            
            layers[index].format = buffer.format
            buffers.append(buffer)
            layers[index].attach(to: engine)
        }
        
        state = .prepared
        
        completion?(true)
    }
    
    override func resumeIfNecessary() throws -> Bool {
        guard isPlaying else {
            return false
        }
        
        var resumed = false
        
        // Resume playback if the player has isPlaying set to true but any of the nodes is stopped
        for (index, layer) in layers.enumerated() where !layer.isPlaying {
            scheduleBuffer(forLayer: index)
            try layer.play()
            resumed = true
        }
        
        return resumed
    }
    
    override func scheduleBuffer(forLayer layer: Int) {
        guard buffers.count > layer, layers.count > layer else {
            GDLogAudioError("Cannot play continuous audio - buffer is nil")
            return
        }
        
        layers[layer].player.scheduleBuffer(buffers[layer], at: nil, options: [.interrupts, .loops], completionHandler: nil)
    }
}
