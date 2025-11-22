//
//  DiscreteAudioPlayer.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import AVFoundation

// Actor used to serialize all mutable state for discrete audio playback layers
// Eliminates data races previously caused by ad hoc Task mutations.
actor DiscretePlayerStateActor {
    struct LayerState {
        var bufferPromise: Promise<AVAudioPCMBuffer?>?
        var bufferQueue: Queue<AVAudioPCMBuffer> = .init()
        var bufferCount = 0
        var playbackDispatchGroupWasEntered = false
        var playbackDispatchGroupWasLeft = false
    }
    private(set) var layerStates: [LayerState]
    private var wasPaused = false

    init(layerCount: Int) {
        layerStates = (0 ..< layerCount).map { _ in LayerState() }
    }

    // Buffer promise access
    func setBufferPromise(_ promise: Promise<AVAudioPCMBuffer?>?, layer: Int) {
        layerStates[layer].bufferPromise = promise
    }
    func getBufferPromise(layer: Int) -> Promise<AVAudioPCMBuffer?>? {
        layerStates[layer].bufferPromise
    }

    // Queue operations
    func enqueueBuffer(_ buffer: AVAudioPCMBuffer, layer: Int) {
        layerStates[layer].bufferQueue.enqueue(buffer)
        layerStates[layer].bufferCount += 1
    }
    func dequeuePlayedBuffer(layer: Int) {
        _ = layerStates[layer].bufferQueue.dequeue()
    }
    func bufferQueueIsEmpty(layer: Int) -> Bool { layerStates[layer].bufferQueue.isEmpty }
    func replaceBufferQueue(layer: Int) -> Queue<AVAudioPCMBuffer> {
        let old = layerStates[layer].bufferQueue
        layerStates[layer].bufferQueue = .init()
        return old
    }
    func restoreQueue(layer: Int, queue: Queue<AVAudioPCMBuffer>) {
        layerStates[layer].bufferQueue = queue
    }

    // Playback dispatch flags
    func markPlaybackEntered(layer: Int) { layerStates[layer].playbackDispatchGroupWasEntered = true }
    func playbackEntered(layer: Int) -> Bool { layerStates[layer].playbackDispatchGroupWasEntered }
    func playbackLeft(layer: Int) -> Bool { layerStates[layer].playbackDispatchGroupWasLeft }
    func markPlaybackLeft(layer: Int) { layerStates[layer].playbackDispatchGroupWasLeft = true }

    // Pause state
    func getWasPaused() -> Bool { wasPaused }
    func setWasPaused(_ paused: Bool) { wasPaused = paused }
}

@MainActor protocol DiscreteAudioPlayerDelegate: AnyObject {
    func onDataPlayedBack(_ playerId: AudioPlayerIdentifier)
    func onLayerFormatChanged(_ playerId: AudioPlayerIdentifier, layer: Int)
}

class DiscreteAudioPlayer: BaseAudioPlayer {
    weak var delegate: DiscreteAudioPlayerDelegate?
    // Serialized mutable state handled by actor
    private let stateActor: DiscretePlayerStateActor
    private var channelPrepareDispatchGroup = DispatchGroup()
    private var channelPlayedBackDispatchGroup = DispatchGroup()
    private var isCancelled = false
    // Queue removed (Phase 7 Step 4); now using actor for serialization.
    required init?(_ sound: Sound) {
        stateActor = DiscretePlayerStateActor(layerCount: sound.layerCount)
        super.init(sound: sound, queue: DispatchQueue.main)
    }
    
    override func prepare(engine: AVAudioEngine, completion: ((_ success: Bool) -> Void)?) {
        state = .preparing
        
        guard let sound = sound as? Sound else {
            completion?(false)
            return
        }
        
        // Validate expected layer count matches sound configuration
        guard layers.count == sound.layerCount else {
            completion?(false)
            return
        }
        
        for index in 0 ..< layers.count {
            channelPrepareDispatchGroup.enter()
            let promise = sound.nextBuffer(forLayer: index)
            Task { await self.stateActor.setBufferPromise(promise, layer: index) }
            promise.then { [weak self] buffer in
                Task { [weak self] in
                    guard let self = self else { return }
                    guard !self.isCancelled, let buffer = buffer else {
                        self.state = .notPrepared
                        self.channelPrepareDispatchGroup.leave()
                        return
                    }
                    self.layers[index].format = buffer.format
                    self.layers[index].attach(to: engine)
                    await self.stateActor.markPlaybackEntered(layer: index)
                    self.channelPlayedBackDispatchGroup.enter()
                    self.channelPrepareDispatchGroup.leave()
                }
            }
        }
        
        // Action to take when the channels all finish preparing
        channelPrepareDispatchGroup.notify(queue: .main) { [weak self] in
            guard self?.state == .preparing else {
                completion?(false)
                return
            }
            
            self?.state = .prepared
            self?.setupPlaybackDispatchGroup()
            completion?(true)
        }
    }
    
    private func setupPlaybackDispatchGroup() {
        // Action to take when all the channels finish playing back
        channelPlayedBackDispatchGroup.notify(queue: queue) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.delegate?.onDataPlayedBack(self.id)
            }
        }
    }
    
    override func resumeIfNecessary() throws -> Bool {
        guard isPlaying else {
            return false
        }
        
        guard layers.contains(where: { !$0.isPlaying }) else {
            // Audio is still playing
            // "Resume" is successful
            return true
        }
        
        var resumed = false
        
        // Resume playback if the player has isPlaying set to true but the node is stopped
        for (index, layer) in layers.enumerated() where !layer.isPlaying {
            schedulePendingBuffers(forChannel: index)
            try layer.play()
            resumed = true
        }
        
        return resumed
    }
    
    override func scheduleBuffer(forLayer layer: Int) {
        Task { [weak self] in
            guard let self = self else { return }
            guard let bufferPromise = await self.stateActor.getBufferPromise(layer: layer) else { return }
            bufferPromise.then { [weak self] (buffer) in
                guard let self = self else { return }
                let format = self.layers[layer].format
                if let buffer = buffer, buffer.format != format {
                    GDLogAudioVerbose("Format needs to be updated (Old: \(format?.description ?? "Nil"), New: \(buffer.format))")
                    self.awaitSilentBuffer(for: layer) { [weak self] in
                        guard let self = self else { return }
                        GDLogAudioVerbose("Reconnecting for new format")
                        self.layers[layer].stop()
                        self.layers[layer].format = buffer.format
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.delegate?.onLayerFormatChanged(self.id, layer: layer)
                        }
                        self.playBuffer(buffer, onChannel: layer)
                        do {
                            try self.layers[layer].play()
                        } catch {
                            GDLogAudioError("Unable to restart the player after audio buffer format change in layer \(layer)")
                            Task { [weak self] in
                                guard let self = self else { return }
                                if !(await self.stateActor.playbackLeft(layer: layer)) {
                                    await self.stateActor.markPlaybackLeft(layer: layer)
                                    self.channelPlayedBackDispatchGroup.leave()
                                }
                            }
                        }
                    }
                    return
                }
                self.playBuffer(buffer, onChannel: layer)
            }
        }
    }
    
    private func schedulePendingBuffers(forChannel layer: Int) {
        guard layers.count > layer else { return }
        Task { [weak self] in
            guard let self = self else { return }
            await self.stateActor.setWasPaused(false)
            let oldQueue = await self.stateActor.replaceBufferQueue(layer: layer)
            var tempQueue = oldQueue
            while let buffer = tempQueue.dequeue() {
                await self.stateActor.enqueueBuffer(buffer, layer: layer)
                self.layers[layer].player.scheduleBuffer(buffer, completionCallbackType: .dataRendered) { [weak self] _ in
                    guard let self = self else { return }
                    Task { [weak self] in
                        guard let self = self else { return }
                        if await self.stateActor.getWasPaused() { return }
                        await self.stateActor.dequeuePlayedBuffer(layer: layer)
                    }
                }
            }
            self.scheduleBuffer(forLayer: layer)
        }
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer?, onChannel layer: Int) {
        guard layers.count > layer, layers[layer].isAttached else {
            GDLogAudioError("Node is no longer connected to the audio engine. Buffer cannot be played!")
            return
        }
        
        // If the buffer is nil, then the Sound object is done rendering buffers so we should
        // wait for all buffers that were scheduled to play to finish playing by having the
        // dispatch group notify us.
        guard let buffer = buffer else {
            layers[layer].player.scheduleBuffer(layers[layer].silentBuffer(), completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self = self else { return }
                Task { [weak self] in
                    guard let self = self else { return }
                    if !(await self.stateActor.bufferQueueIsEmpty(layer: layer)) {
                        await self.stateActor.setWasPaused(true)
                        return
                    }
                    if !(await self.stateActor.playbackEntered(layer: layer)) {
                        GDLogAudioVerbose("Silent buffer played back, but dispatch group was never entered!")
                        return
                    }
                    if await self.stateActor.playbackLeft(layer: layer) {
                        GDLogAudioVerbose("Silent buffer played back, but dispatch group was already left!")
                        return
                    }
                    await self.stateActor.markPlaybackLeft(layer: layer)
                    self.channelPlayedBackDispatchGroup.leave()
                }
            }
            return
        }
        
        // Schedule this buffer (and use the dispatch group to know when it is done playing)
        // Serialize mutations to layer state on the queue
        Task { [weak self] in
            guard let self = self else { return }
            await self.stateActor.enqueueBuffer(buffer, layer: layer)
        }
        layers[layer].player.scheduleBuffer(buffer, completionCallbackType: .dataRendered) { [weak self] (_) in
            guard let self = self else { return }
            Task { [weak self] in
                guard let self = self else { return }
                if await self.stateActor.getWasPaused() { return }
                await self.stateActor.dequeuePlayedBuffer(layer: layer)
            }
        }
        
        // Request the next buffer and schedule it
        guard let sound = sound as? Sound else {
            return
        }
        
        let promise = sound.nextBuffer(forLayer: layer)
        Task { await self.stateActor.setBufferPromise(promise, layer: layer) }
        scheduleBuffer(forLayer: layer)
    }
    
    private func awaitSilentBuffer(for layer: Int, callback: @escaping () -> Void) {
        guard layers.count > layer, layers[layer].isAttached else {
            GDLogAudioError("Node is no longer connected to the audio engine. Buffer cannot be played!")
            return
        }
        
        let silentBuffer = layers[layer].silentBuffer()
        
        layers[layer].player.scheduleBuffer(silentBuffer, completionCallbackType: .dataPlayedBack) { _ in
            Task { @MainActor in callback() }
        }
    }
    
    override func stop() {
        // Allow for cancelling sounds that are still being prepared (e.g. async TTS that hasn't returned a buffer yet)
        guard state == .prepared else {
            if state == .preparing {
                isCancelled = true
            }
            
            return
        }
        
        super.stop()
    }
}
