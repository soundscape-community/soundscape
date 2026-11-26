//
//  AudioFileStore.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import Combine

class AudioFileStore: ObservableObject {
    @Published var isDownloaded: Bool = false
    @Published var duration: TimeInterval = 0.0
    @Published var elapsed: TimeInterval = 0.0
    @Published var isPlaying: Bool = false
    
    private(set) var activityID: String?
    private(set) var remoteURL: URL?
    
    private(set) var localURL: URL?
    private(set) var playerID: PlaybackHandle?
    private var timer: Timer?
    private var downloadListener: AnyCancellable?
    
    /// Initializer that should only be used during design-time. This initializer overrides the default
    /// behavior in order to fake the isDownloaded state value to match the provided value.
    ///
    /// - Parameter overrideIsDownloaded: Override value to apply during design time
    convenience init(overrideIsDownloaded: Bool = false) {
        self.init()
        
        isDownloaded = overrideIsDownloaded
    }
    
    deinit {
        downloadListener?.cancel()
        downloadListener = nil
        playerID?.stop()
        timer?.invalidate()
        
        
    }
    
    func load(activityID: String, remoteURL: URL) {
        self.activityID = activityID
        self.remoteURL = remoteURL
        
        defer {
            if let url = localURL {
                updateDuration(url)
            }
        }
        
        guard !AuthoredActivityLoader.shared.audioClipExists(activityID: activityID, remoteURL: remoteURL) else {
            localURL = AuthoredActivityLoader.shared.localAudioFileURL(activityID: activityID, remoteURL: remoteURL)
            isDownloaded = true
            return
        }
        
        downloadListener = NotificationCenter.default.publisher(for: .activityAudioClipDownloaded).receive(on: RunLoop.main).sink { notification in
            guard let id = notification.userInfo?[AuthoredActivityLoader.Keys.activityId] as? String, id == activityID else {
                return
            }
            
            guard let remote = notification.userInfo?[AuthoredActivityLoader.Keys.activityId] as? String, remote == remoteURL.path else {
                return
            }
            
            guard let local = notification.userInfo?[AuthoredActivityLoader.Keys.activityId] as? String else {
                return
            }
            
            self.localURL = URL(fileURLWithPath: local)
            self.isDownloaded = true
            if let url = self.localURL { self.updateDuration(url) }
        }
    }
    
    private func updateDuration(_ url: URL) {
        guard let file = try? AVAudioFile(forReading: url) else { return }
        duration = Double(file.length) / file.processingFormat.sampleRate
    }

    func start() {
        
        guard let url = localURL else {
            return
        }
        
        let handle = AppContext.shared.audioEngine.play(GenericSound(url))
        playerID = handle
        Task { @MainActor [weak self] in
            _ = await handle.completion()
            guard let self, self.playerID == handle else { return }
            self.cleanupFinishedPlayer()
        }

        let tickTock = Timer(timeInterval: 0.05, repeats: true, block: { [weak self] _ in self?.elapsed += 0.05 })
        RunLoop.main.add(tickTock, forMode: .default)
        timer = tickTock
        
        isPlaying = true
    }
    
    func stop() {
        
        guard let id = playerID else {
            return
        }
        
        id.stop()
        cleanupFinishedPlayer()
    }
    
    private func cleanupFinishedPlayer() {
        isPlaying = false
        
        
        
        timer?.invalidate()
        timer = nil
        elapsed = 0.0
        
        playerID = nil
    }
}
