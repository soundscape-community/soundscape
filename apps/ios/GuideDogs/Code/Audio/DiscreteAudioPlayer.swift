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
        var bufferTask: Task<AVAudioPCMBuffer?, Never>?
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

    // Buffer task access
    func setBufferTask(_ task: Task<AVAudioPCMBuffer?, Never>?, layer: Int) {
        layerStates[layer].bufferTask = task
    }
    func getBufferTask(layer: Int) -> Task<AVAudioPCMBuffer?, Never>? {
        layerStates[layer].bufferTask
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

    // Centralized playback group completion logic for a layer finishing naturally.
    // Returns true if the caller should leave the external DispatchGroup.
    func attemptLeaveIfFinished(layer: Int) -> Bool {
        if !layerStates[layer].bufferQueue.isEmpty {
            wasPaused = true
            return false
        }
        guard layerStates[layer].playbackDispatchGroupWasEntered else { return false }
        guard !layerStates[layer].playbackDispatchGroupWasLeft else { return false }
        layerStates[layer].playbackDispatchGroupWasLeft = true
        return true
    }

    // Force a leave (error recovery path). Returns true if group should be left.
    func attemptForceLeave(layer: Int) -> Bool {
        guard !layerStates[layer].playbackDispatchGroupWasLeft else { return false }
        layerStates[layer].playbackDispatchGroupWasLeft = true
        return true
    }
}

private enum DiscreteAudioPlayerError: Error {
    case missingInitialBuffer
}

@MainActor protocol DiscreteAudioPlayerDelegate: AnyObject {
    func onDataPlayedBack(_ playerId: AudioPlayerIdentifier)
    func onLayerFormatChanged(_ playerId: AudioPlayerIdentifier, layer: Int)
}

@MainActor
class DiscreteAudioPlayer: BaseAudioPlayer {
    weak var delegate: DiscreteAudioPlayerDelegate?
    // Serialized mutable state handled by actor
    private let stateActor: DiscretePlayerStateActor
    private var prepareTask: Task<Void, Never>?
    private var playbackWatcherTask: Task<Void, Never>?
    private var playbackContinuation: AsyncStream<Int>.Continuation?
    private var isCancelled = false
    // Queue removed (Phase 7 Step 4); now using actor for serialization.
    required init?(_ sound: Sound) {
        stateActor = DiscretePlayerStateActor(layerCount: sound.layerCount)
        super.init(sound: sound)
    }
    
    deinit {
        prepareTask?.cancel()
        Task { @MainActor [weak self] in
            self?.cancelPlaybackWatcher()
        }
    }
    
    override func prepare(engine: AVAudioEngine, completion: ((_ success: Bool) -> Void)?) {
        state = .preparing
        
        guard let sound = sound as? Sound else {
            completion?(false)
            return
        }
        
        guard layers.count == sound.layerCount else {
            completion?(false)
            return
        }
        
        isCancelled = false
        prepareTask?.cancel()
        prepareTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer { self.prepareTask = nil }
            let success = await self.prepareLayers(engine: engine, sound: sound)
            guard !Task.isCancelled else { return }
            if success {
                self.state = .prepared
                self.startPlaybackCompletionWatcher()
            } else {
                self.state = .notPrepared
            }
            completion?(success)
        }
    }
    
    private func prepareLayers(engine: AVAudioEngine, sound: Sound) async -> Bool {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for index in 0 ..< layers.count {
                    group.addTask { [weak self] in
                        guard let self = self else { return }
                        try await self.prepareLayer(at: index, engine: engine, sound: sound)
                    }
                }
                try await group.waitForAll()
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            GDLogAudioError("Failed to prepare discrete player: \(error)")
            return false
        }
    }
    
    private func prepareLayer(at index: Int, engine: AVAudioEngine, sound: Sound) async throws {
        try Task.checkCancellation()
        guard !isCancelled else { throw CancellationError() }
        let bufferTask = Task { await sound.nextBuffer(forLayer: index) }
        await stateActor.setBufferTask(bufferTask, layer: index)
        let buffer = await bufferTask.value
        try Task.checkCancellation()
        guard !isCancelled, let buffer = buffer else {
            throw DiscreteAudioPlayerError.missingInitialBuffer
        }
        layers[index].format = buffer.format
        layers[index].attach(to: engine)
        await stateActor.markPlaybackEntered(layer: index)
    }
    
    private func startPlaybackCompletionWatcher() {
        cancelPlaybackWatcher()
        
        guard !layers.isEmpty else {
            delegate?.onDataPlayedBack(id)
            return
        }
        
        let stream = AsyncStream<Int> { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.playbackContinuation = nil
                }
            }
            Task { @MainActor [weak self] in
                self?.playbackContinuation = continuation
            }
        }
        
        playbackWatcherTask = Task { @MainActor [weak self] in
            var finishedLayers = Set<Int>()
            for await layerIndex in stream {
                guard let self = self else { return }
                finishedLayers.insert(layerIndex)
                if finishedLayers.count == self.layers.count {
                    self.delegate?.onDataPlayedBack(self.id)
                    self.playbackContinuation?.finish()
                    break
                }
            }
        }
    }
    
    private func signalLayerCompletion(for layer: Int) {
        playbackContinuation?.yield(layer)
    }

    private func cancelPlaybackWatcher() {
        playbackWatcherTask?.cancel()
        playbackWatcherTask = nil
        playbackContinuation?.finish()
        playbackContinuation = nil
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
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let bufferTask = await self.stateActor.getBufferTask(layer: layer) else { return }
            let buffer = await bufferTask.value
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
                            Task { @MainActor [weak self] in
                                guard let self = self else { return }
                                if await self.stateActor.attemptForceLeave(layer: layer) {
                                            self.signalLayerCompletion(for: layer)
                                }
                            }
                    }
                }
                return
            }
            self.playBuffer(buffer, onChannel: layer)
        }
    }

    
    
    private func schedulePendingBuffers(forChannel layer: Int) {
        guard layers.count > layer else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.stateActor.setWasPaused(false)
            let oldQueue = await self.stateActor.replaceBufferQueue(layer: layer)
            var tempQueue = oldQueue
            while let buffer = tempQueue.dequeue() {
                await self.stateActor.enqueueBuffer(buffer, layer: layer)
                self.layers[layer].player.scheduleBuffer(buffer, completionCallbackType: .dataRendered) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor [weak self] in
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
        
        // If the buffer is nil, then the Sound object is done rendering buffers so we schedule
        // a silent buffer to detect when playback actually drains and signal the async watcher.
        guard let buffer = buffer else {
            layers[layer].player.scheduleBuffer(layers[layer].silentBuffer(), completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if await self.stateActor.attemptLeaveIfFinished(layer: layer) {
                        self.signalLayerCompletion(for: layer)
                    } else if await self.stateActor.playbackLeft(layer: layer) {
                        GDLogAudioVerbose("Silent buffer played back, but dispatch group was already left!")
                    } else if !(await self.stateActor.playbackEntered(layer: layer)) {
                        GDLogAudioVerbose("Silent buffer played back, but dispatch group was never entered!")
                    }
                }
            }
            return
        }
        
        // Schedule this buffer and rely on the actor queue to track render completions.
        Task { [weak self] in
            guard let self = self else { return }
            await self.stateActor.enqueueBuffer(buffer, layer: layer)
        }
        layers[layer].player.scheduleBuffer(buffer, completionCallbackType: .dataRendered) { [weak self] (_) in
            guard let self = self else { return }
                    Task { @MainActor [weak self] in
                guard let self = self else { return }
                if await self.stateActor.getWasPaused() { return }
                await self.stateActor.dequeuePlayedBuffer(layer: layer)
            }
        }
        
        // Request the next buffer and schedule it
        guard let sound = sound as? Sound else {
            return
        }
        
        let bufferTask = Task { await sound.nextBuffer(forLayer: layer) }

        // Ensure the actor state is updated with the new task before we try to schedule
        // the next buffer — avoids a race where `scheduleBuffer` reads `nil` if the
        // set call races with the scheduler.
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.stateActor.setBufferTask(bufferTask, layer: layer)
            self.scheduleBuffer(forLayer: layer)
        }
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
        if state == .preparing {
            isCancelled = true
            prepareTask?.cancel()
            prepareTask = nil
            return
        }
        
        guard state == .prepared else {
            return
        }
        
        super.stop()
        cancelPlaybackWatcher()
    }
}
