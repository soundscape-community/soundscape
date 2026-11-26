//
//  AudioEngine.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AudioToolbox
import AVFoundation
import CoreLocation
import UIKit

extension Notification.Name {
    static let audioEngineStateChanged = Notification.Name("GDAAudioEngineStateChanged")
}

extension AudioCoordinate {
    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}

// The control queue is the sole owner of graph, session and operation state.
// File preparation runs on a worker and transfers each finished buffer once.
// Remove the Sendable escape hatch when the iOS renderer can use an isolated executor at the deployment baseline.
final class AudioEngine: AudioPlayback, AudioSessionManagerDelegate, @unchecked Sendable {
    enum State: Int { case stopped, starting, started }
    enum Keys { static let audioEngineStateKey = "GDAAudioEngineStateKey" }

    private enum Channel { case effects, speech, beacon }

    private final class Source {
        let player = AVAudioPlayerNode()
        let equalizer: AVAudioUnitEQ
        let environment: AVAudioEnvironmentNode?
        let spatialMixer: AVAudioMixerNode?
        let type: SoundType
        let channel: Channel
        let voiceEQ: EQParameters?
        var speech: SpeechPCMSource?
        var queued = 0
        var ended = false
        var readyToPlay = false
        let format: AVAudioFormat
        var selectionGain: Float = 1

        init(type: SoundType, channel: Channel, format: AVAudioFormat, voiceEQ: EQParameters?, spatial: Bool) {
            self.format = format
            self.type = type
            self.channel = channel
            self.voiceEQ = voiceEQ
            equalizer = AVAudioUnitEQ(numberOfBands: voiceEQ?.bandParameters.count ?? 0)
            environment = spatial ? AVAudioEnvironmentNode() : nil
            spatialMixer = spatial ? AVAudioMixerNode() : nil
        }
    }

    private final class Beacon {
        let description: AdaptiveBeacon
        let source: Source
        let buffers: [AudioAsset: AVAudioPCMBuffer]
        let silence: AVAudioPCMBuffer
        let timing: BeaconTiming
        var selected: AudioAsset?
        var hasScheduled = false
        var finishing = false

        init(_ description: AdaptiveBeacon, source: Source, buffers: [AudioAsset: AVAudioPCMBuffer], silence: AVAudioPCMBuffer) {
            self.description = description
            self.source = source
            self.buffers = buffers
            self.silence = silence
            timing = BeaconTiming(intro: Int64(description.intro.flatMap { buffers[$0]?.frameLength } ?? 0),
                                  phrase: Int64(silence.frameLength), beats: Int64(description.beats))
        }
    }

    private final class Operation {
        let request: AudioRequest
        let completion: PlaybackCompletion
        var sources: [Source] = []
        var beacon: Beacon?
        var gain: Float
        var fadeGeneration: UInt64 = 0
        var focus: Double?
        var paused = false
        var finishRequested = false
        var generation: UInt64 = 0
        var recovering = false
        var speechSources: [UUID: SpeechPCMSource] = [:]
        var speechPlayers: [UUID: Source] = [:]
        var preparation = [UUID: DispatchWorkItem]()

        init(_ request: AudioRequest, completion: PlaybackCompletion) {
            self.request = request
            self.gain = request.initialGain
            self.completion = completion
        }
    }

    private let control = DispatchQueue(label: "org.soundscape.audio.control")
    private let files = DispatchQueue(label: "org.soundscape.audio.assets", qos: .userInitiated)
    private let sessionManager: AudioSessionManager
    private let envSettings: EnvironmentSettingsProvider
    private let canStart: @Sendable () -> Bool
    private var engine = AVAudioEngine()
    private var state = State.stopped
    private var operations: [ObjectIdentifier: Operation] = [:]
    private var observers: [NSObjectProtocol] = []
    private var graphObserver: NSObjectProtocol?
    private var headings: [Heading] = []
    private var interrupted = false
    private var wantsRunning = false
    private var routingCallback: ((AVAudioSession.PortOverride) -> Void)?
    private var recordingFile: ExtAudioFileRef?
    private struct Status {
        var mixes: Bool
        var transientCount = 0
        var recording = false
    }
    private let statusLock = NSLock()
    private var status: Status

    private struct Scene {
        var location: AudioCoordinate?
        var presentation: Double?
        var yaw: Double = 0
        var device: Double?
        var collection: Double?
    }
    private var scene = Scene()
    private let sceneLock = NSLock()
    private var pendingScene = Scene()
    private var sceneScheduled = false

    private let makeSpeech: (String, String?, @escaping SpeechPCMOutput) -> SpeechPCMSource
    private static let voiceFilters: [String: EQParameters] = {
        struct VoiceEQ: Decodable { let id: String; let filter: EQParameters }
        guard let url = Bundle.main.url(forResource: "voiceFilters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let filters = try? JSONDecoder().decode([VoiceEQ].self, from: data) else { return [:] }
        return filters.reduce(into: [:]) { $0[$1.id] = $1.filter }
    }()

    init(envSettings: EnvironmentSettingsProvider, mixWithOthers: Bool,
         canStart: @escaping @Sendable () -> Bool = { AppContext.appState != .inactive },
         makeSpeech: @escaping (String, String?, @escaping SpeechPCMOutput) -> SpeechPCMSource = {
             IOSSpeechPCMSource(text: $0, voiceID: $1, output: $2)
         }) {
        self.status = Status(mixes: mixWithOthers)
        self.envSettings = envSettings
        self.canStart = canStart
        self.makeSpeech = makeSpeech
        sessionManager = AudioSessionManager(mixWithOthers: mixWithOthers, control: control)
        sessionManager.delegate = self
        observeGraph()
        control.async { [weak self] in self?.sessionManager.configure() }
        let center = NotificationCenter.default
        for name in [Notification.Name.beaconVolumeChanged, .ttsVolumeChanged, .otherVolumeChanged, .beaconGainChanged, .beaconRingingAngleChanged] {
            observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.control.async { [weak self] in self?.updateScene() }
            })
        }
        for name in [AVAudioSession.routeChangeNotification, UIAccessibility.monoAudioStatusDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.control.async { [weak self] in
                    guard let self, self.wantsRunning, !self.interrupted else { return }
                    if self.isInMonoMode != self.graphMono || !self.engine.isRunning { self.recover() }
                }
            })
        }
        observers.append(center.addObserver(forName: .callStatusChanged, object: nil, queue: nil) { [weak self] notification in
            guard let value = notification.userInfo?[CallManager.Keys.callStatusTypeKey] as? UInt,
                  CallStatusType(rawValue: value) == .ended else { return }
            self?.control.async { [weak self] in
                guard let self, self.wantsRunning, self.interrupted, self.sessionManager.activate(force: true) else { return }
                self.interrupted = false
                self.recoverIfStopped()
            }
        })
        observers.append(center.addObserver(forName: .appDidBecomeActive, object: nil, queue: nil) { [weak self] _ in
            self?.control.async { [weak self] in
                guard let self, self.wantsRunning else { return }
                if self.interrupted {
                    guard self.sessionManager.activate(force: true) else { return }
                    self.interrupted = false
                }
                self.recoverIfStopped()
            }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        if let graphObserver { NotificationCenter.default.removeObserver(graphObserver) }
        stopRecordingOnControl()
        for operation in operations.values { operation.completion.resolve(.stopped) }
    }

    var session: AVAudioSession { sessionManager.session }
    var outputType: String { sessionManager.outputType }
    var mixWithOthers: Bool {
        get { statusLock.withLock { status.mixes } }
        set {
            statusLock.withLock { status.mixes = newValue }
            control.async {
                self.sessionManager.mixWithOthers = newValue
                self.recoverIfStopped()
            }
        }
    }
    var isInMonoMode: Bool { session.outputNumberOfChannels == 1 || UIAccessibility.isMonoAudioEnabled }
    private var graphMono = false

    func bindHeadings(presentation: Heading, device: Heading, collection: Heading) {
        headings = [presentation, device, collection]
        updateSensor {
            $0.presentation = presentation.value
            $0.yaw = presentation.value ?? 0
            $0.device = device.value
            $0.collection = collection.value
        }
        presentation.onHeadingDidUpdate { [weak self] heading in
            self?.updateSensor {
                $0.presentation = heading?.value
                if let heading { $0.yaw = heading.value }
            }
        }
        device.onHeadingDidUpdate { [weak self] heading in self?.updateSensor { $0.device = heading?.value } }
        collection.onHeadingDidUpdate { [weak self] heading in self?.updateSensor { $0.collection = heading?.value } }
    }

    func updateUserLocation(_ location: CLLocation) {
        let position = AudioCoordinate(location)
        updateSensor { $0.location = position }
    }

    private func updateSensor(_ update: (inout Scene) -> Void) {
        let schedule = sceneLock.withLock {
            update(&pendingScene)
            guard !sceneScheduled else { return false }
            sceneScheduled = true
            return true
        }
        if schedule {
            control.async { [weak self] in
                guard let self else { return }
                self.scene = self.sceneLock.withLock {
                    self.sceneScheduled = false
                    return self.pendingScene
                }
                self.updateScene()
            }
        }
    }

    func start() {
        control.async {
            self.wantsRunning = true
            self.recoverIfStopped()
        }
    }

    func shutdown() {
        control.async {
            self.wantsRunning = false
            for operation in Array(self.operations.values) { self.end(operation, .stopped) }
            self.stopRecordingOnControl()
            self.engine.stop()
            self.sessionManager.deactivate()
            self.publish(.stopped)
        }
    }

    @discardableResult
    func play(_ request: AudioRequest) -> PlaybackHandle {
        let completion = PlaybackCompletion()
        let id = ObjectIdentifier(completion)
        let handle = PlaybackHandle(state: completion) { [weak self, weak completion] command in
            self?.control.async { [weak self, weak completion] in
                guard let self, let completion, let operation = self.operations[id], operation.completion === completion else { return }
                switch command {
                case .stop: self.end(operation, .stopped)
                case .finish:
                    operation.finishRequested = true
                    if self.interrupted { self.end(operation, .interrupted); return }
                    if let beacon = operation.beacon {
                        self.finishBeacon(beacon, operation: operation)
                        if operation.paused { beacon.source.player.play() }
                    }
                    else if !operation.request.sounds.contains(where: { if case .beacon = $0.content { return true }; return false }),
                            operation.request.loops { self.end(operation, .stopped) }
                case .paused(let paused):
                    operation.paused = paused
                    for source in operation.sources where source.readyToPlay {
                        if paused { source.player.pause(); source.speech?.pause() }
                        else { source.player.play(); if source.queued < 12 { source.speech?.resume() } }
                    }
                case .focus(let bearing):
                    operation.focus = bearing
                    if let beacon = operation.beacon { self.updateBeacon(beacon, operation: operation) }
                case .fade(let gain, let seconds, let stop):
                    self.fade(operation, to: gain, seconds: seconds, stop: stop)
                case .gain(let gain):
                    operation.fadeGeneration &+= 1
                    operation.gain = max(0, min(gain, 1))
                    operation.sources.forEach { self.update($0, operation: operation) }
                }
            }
        }
        control.async {
            guard !completion.stopRequested else { completion.resolve(.stopped); return }
            guard !self.interrupted else { completion.resolve(.interrupted); return }
            guard self.wantsRunning, self.engine.isRunning || self.startGraph() else {
                completion.resolve(.failed("Audio engine unavailable"))
                return
            }
            let operation = Operation(request, completion: completion)
            self.operations[id] = operation
            if request.transient { self.statusLock.withLock { self.status.transientCount += 1 } }
            self.run(operation)
        }
        return handle
    }

    private func fade(_ operation: Operation, to target: Float, seconds: Double, stop: Bool) {
        operation.fadeGeneration &+= 1
        let token = operation.fadeGeneration
        let start = DispatchTime.now().uptimeNanoseconds
        let initial = operation.gain
        @Sendable func tick() {
            guard alive(operation), operation.fadeGeneration == token else { return }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
            let progress = seconds > 0 && seconds.isFinite ? min(1, elapsed / seconds) : 1
            operation.gain = initial + (max(0, min(1, target)) - initial) * Float(progress)
            operation.sources.forEach { update($0, operation: operation) }
            if progress < 1 {
                control.asyncAfter(deadline: .now() + .milliseconds(30)) { tick() }
            } else if stop {
                end(operation, .stopped)
            }
        }
        tick()
    }

    var hasTransientAudio: Bool {
        statusLock.withLock { status.transientCount > 0 }
    }

    func stopTransientAudio() {
        control.async {
            for operation in Array(self.operations.values) where operation.request.transient {
                self.end(operation, .stopped)
            }
        }
    }

    private func run(_ operation: Operation) {
        sequence(operation.request.sounds[...], operation: operation) { [weak self, weak operation] in
            guard let self, let operation else { return }
            self.end(operation, .completed)
        }
    }

    private func alive(_ operation: Operation) -> Bool {
        operations[ObjectIdentifier(operation.completion)] === operation && !operation.completion.stopRequested
    }

    private func end(_ operation: Operation, _ result: PlaybackResult) {
        guard operations.removeValue(forKey: ObjectIdentifier(operation.completion)) != nil else { return }
        if operation.request.transient { statusLock.withLock { status.transientCount -= 1 } }
        reset(operation)
        operation.completion.resolve(operation.completion.stopRequested ? .stopped : result)
    }

    private func reset(_ operation: Operation) {
        operation.generation &+= 1
        operation.preparation.values.forEach { $0.cancel() }
        operation.preparation.removeAll()
        operation.speechSources.values.forEach { $0.cancel() }
        operation.speechSources.removeAll()
        operation.speechPlayers.removeAll()
        operation.sources.forEach(detach)
        operation.sources.removeAll()
        operation.beacon = nil
    }

    private typealias LayerReady = ([Source]) -> Void

    private func begin(_ sources: [Source], operation: Operation) {
        let time = sources.count > 1 ? AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.02)) : nil
        for source in sources {
            source.readyToPlay = true
            if !operation.paused || operation.finishRequested { source.player.play(at: time) }
        }
    }

    private func sequence(_ sounds: ArraySlice<any Sound>, operation: Operation, ready: LayerReady? = nil,
                          done: @escaping () -> Void) {
        guard alive(operation) else { return }
        guard let sound = sounds.first else { ready?([]); done(); return }
        render(sound, operation: operation, ready: ready) { [weak self, weak operation] in
            guard let self, let operation else { return }
            self.sequence(sounds.dropFirst(), operation: operation, done: done)
        }
    }

    private func render(_ sound: any Sound, operation: Operation, ready: LayerReady? = nil, done: @escaping () -> Void) {
        guard alive(operation) else { return }
        switch sound.content {
        case .sequence(let sounds): sequence(sounds[...], operation: operation, ready: ready, done: done)
        case .parallel(let sounds):
            guard !sounds.isEmpty else { ready?([]); done(); return }
            var remaining = sounds.count
            var awaitingStart = sounds.count
            var sources: [Source] = []
            for sound in sounds {
                render(sound, operation: operation, ready: { [weak self, weak operation] layer in
                    sources.append(contentsOf: layer)
                    awaitingStart -= 1
                    if awaitingStart == 0 {
                        if let ready { ready(sources) }
                        else if let self, let operation { self.begin(sources, operation: operation) }
                    }
                }) {
                    remaining -= 1
                    if remaining == 0 { done() }
                }
            }
        case .asset(let asset):
            load([asset], operation: operation) { [weak self, weak operation] buffers in
                guard let self, let operation, let buffer = buffers[asset] else { return }
                let source = self.attach(type: sound.type, channel: .effects, format: buffer.format, operation: operation)
                if operation.request.loops {
                    source.player.scheduleBuffer(buffer, at: nil, options: .loops)
                } else {
                    self.schedule(buffer, source: source, operation: operation) {
                        self.remove(source, operation: operation)
                        done()
                    }
                }
                if let ready { ready([source]) } else { self.begin([source], operation: operation) }
            }
        case .speech(let text): speak(text, type: sound.type, operation: operation, ready: ready, done: done)
        case .beacon(let beacon): prepareBeacon(beacon, type: sound.type, operation: operation, ready: ready)
        }
    }

    private func load(_ assets: [AudioAsset], operation: Operation, ready: @escaping ([AudioAsset: AVAudioPCMBuffer]) -> Void) {
        let generation = operation.generation
        let token = UUID()
        let work = DispatchWorkItem { [weak self, weak operation] in
            let result = Result { try assets.reduce(into: [:]) { $0[$1] = try Self.buffer(for: $1) } }
            self?.control.async { [weak self, weak operation] in
                guard let self, let operation, self.alive(operation), operation.generation == generation else { return }
                operation.preparation.removeValue(forKey: token)
                switch result {
                case .success(let buffers): ready(buffers)
                case .failure(let error): self.end(operation, .failed(String(describing: error)))
                }
            }
        }
        operation.preparation[token] = work
        files.async(execute: work)
    }

    private static func buffer(for asset: AudioAsset) throws -> AVAudioPCMBuffer {
        let url: URL?
        var temporaryDirectory: URL?
        defer {
            if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
        }
        switch asset {
        case .bundle(let name, let ext): url = Bundle.main.url(forResource: name, withExtension: ext)
        case .file(let file): url = file
        case .catalog(let name, let ext):
            let override = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first?.appendingPathComponent(name).appendingPathExtension(ext)
            if let override, FileManager.default.fileExists(atPath: override.path) {
                url = override
            } else if let data = NSDataAsset(name: name)?.data {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                temporaryDirectory = directory
                let file = directory.appendingPathComponent("audio").appendingPathExtension(ext)
                try data.write(to: file)
                url = file
            } else { url = Bundle.main.url(forResource: name, withExtension: ext) }
        }
        guard let url else { throw AudioPreparationError.asset }
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0, file.length <= Int64(UInt32.max),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AudioPreparationError.format
        }
        try file.read(into: buffer)
        return buffer
    }

    private func attach(type: SoundType, channel: Channel, format: AVAudioFormat, voiceEQ: EQParameters? = nil, operation: Operation) -> Source {
        let spatial = type.position(listener: scene.location, heading: 0, ring: 1) != nil || {
            if case .localized = type { return true }
            return false
        }()
        let source = Source(type: type, channel: channel, format: format, voiceEQ: voiceEQ,
                            spatial: spatial && format.channelCount == 1 && !graphMono)
        engine.attach(source.player)
        engine.attach(source.equalizer)
        engine.connect(source.player, to: source.equalizer, format: format)
        if let environment = source.environment, let mixer = source.spatialMixer {
            engine.attach(environment)
            engine.attach(mixer)
            environment.distanceAttenuationParameters.referenceDistance = 2
            environment.reverbParameters.enable = envSettings.envRenderingReverbEnable
            environment.reverbParameters.level = envSettings.envRenderingReverbLevel
            environment.reverbParameters.loadFactoryReverbPreset(envSettings.envRenderingReverbPreset)
            if envSettings.envReverbFilterActive {
                let band = environment.reverbParameters.filterParameters
                band.bandwidth = envSettings.envReverbFilterBandwidth
                band.bypass = envSettings.envReverbFilterBypass
                band.filterType = envSettings.envReverbFilterType
                band.frequency = envSettings.envReverbFilterFrequency
                band.gain = envSettings.envReverbFilterGain
            }
            engine.connect(source.equalizer, to: mixer, format: format)
            engine.connect(mixer, to: environment, format: format)
            let stereo = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 2)
            engine.connect(environment, to: engine.mainMixerNode, format: stereo)
            mixer.renderingAlgorithm = envSettings.envRenderingAlgorithm
        } else {
            engine.connect(source.equalizer, to: engine.mainMixerNode, format: format)
        }
        if let voiceEQ {
            for (band, filter) in zip(source.equalizer.bands, voiceEQ.bandParameters) {
                band.bandwidth = filter.bandwidth
                band.bypass = filter.bypass
                band.filterType = filter.filterType
                band.frequency = filter.frequency
                band.gain = filter.gain
            }
        }
        operation.sources.append(source)
        update(source, operation: operation)
        return source
    }

    private func detach(_ source: Source) {
        source.speech?.cancel()
        source.speech = nil
        source.player.stop()
        engine.detach(source.player)
        engine.detach(source.equalizer)
        if let mixer = source.spatialMixer { engine.detach(mixer) }
        if let environment = source.environment { engine.detach(environment) }
    }

    private func remove(_ source: Source, operation: Operation) {
        guard let index = operation.sources.firstIndex(where: { $0 === source }) else { return }
        operation.sources.remove(at: index)
        detach(source)
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, source: Source, operation: Operation,
                          at time: AVAudioTime? = nil, options: AVAudioPlayerNodeBufferOptions = [], done: @escaping () -> Void) {
        let generation = operation.generation
        source.player.scheduleBuffer(buffer, at: time, options: options, completionCallbackType: .dataPlayedBack) { [weak self, weak operation, weak source] _ in
            self?.control.async { [weak self, weak operation, weak source] in
                guard let self, let operation, let source, self.alive(operation), operation.generation == generation,
                      operation.sources.contains(where: { $0 === source }) else { return }
                guard self.engine.isRunning else { self.recoverIfStopped(); return }
                done()
            }
        }
    }

    private func speak(_ text: String, type: SoundType, operation: Operation, ready: LayerReady?, done: @escaping () -> Void) {
        let locale = LocalizationContext.currentAppLocale
        let voice = SettingsContext.shared.voiceId ?? TTSConfigHelper.defaultVoice(forLocale: locale)?.identifier
        let generation = operation.generation
        let pending = SpeechInput()
        let id = ObjectIdentifier(operation.completion)
        let speech = makeSpeech(text, voice) { [weak self, weak completion = operation.completion] result in
            guard pending.accept(result) else { return }
            self?.control.async { [weak self, weak completion] in
                guard let self, let completion, let operation = self.operations[id], operation.completion === completion,
                      self.alive(operation), operation.generation == generation, let result = pending.take() else { return }
                switch result {
                case .failure(let error): self.end(operation, .failed(String(describing: error)))
                case .success(nil):
                    guard let source = operation.speechPlayers[pending.id] else {
                        self.end(operation, .failed("Speech synthesis produced no audio"))
                        return
                    }
                    guard !source.ended else { return }
                    source.ended = true
                    source.speech = nil
                    if source.queued == 0 {
                        operation.speechPlayers.removeValue(forKey: pending.id)
                        self.remove(source, operation: operation)
                        done()
                    }
                case .success(let buffer?):
                    let source: Source
                    let firstBuffer = operation.speechPlayers[pending.id] == nil
                    if let current = operation.speechPlayers[pending.id] {
                        source = current
                    } else {
                        source = self.attach(type: type, channel: .speech, format: buffer.format,
                                             voiceEQ: voice.flatMap { Self.voiceFilters[$0] }, operation: operation)
                        source.speech = operation.speechSources.removeValue(forKey: pending.id)
                        operation.speechPlayers[pending.id] = source
                    }
                    guard !source.ended else { return }
                    guard source.format == buffer.format else {
                        self.end(operation, .failed("Speech PCM format changed mid-utterance"))
                        return
                    }
                    guard source.queued < 64 else {
                        self.end(operation, .failed(String(describing: AudioPreparationError.speechBufferLimit)))
                        return
                    }
                    source.queued += 1
                    if source.queued == 12 { source.speech?.pause() }
                    self.schedule(buffer, source: source, operation: operation) { [weak self, weak source, weak operation] in
                        guard let self, let source, let operation else { return }
                        source.queued -= 1
                        if source.queued == 4 && !operation.paused { source.speech?.resume() }
                        if source.ended && source.queued == 0 {
                            operation.speechPlayers.removeValue(forKey: pending.id)
                            self.remove(source, operation: operation)
                            done()
                        }
                    }
                    if firstBuffer {
                        if let ready { ready([source]) } else { self.begin([source], operation: operation) }
                    }
                }
            }
        }
        operation.speechSources[pending.id] = speech
        speech.start()
    }

    // Synthesis callbacks may arrive faster than the graph consumes them.
    // The lock guards the bounded PCM ingress. Buffers become immutable before crossing into it.
    private final class SpeechInput: @unchecked Sendable {
        let id = UUID()
        private let lock = NSLock()
        private var buffers: [Result<AVAudioPCMBuffer?, Error>] = []
        private var terminal = false

        func accept(_ result: Result<AVAudioPCMBuffer?, Error>) -> Bool {
            lock.withLock {
                guard !terminal else { return false }
                if buffers.count == 64 {
                    terminal = true
                    buffers.append(.failure(AudioPreparationError.speechBufferLimit))
                } else {
                    switch result {
                    case .success(.some): break
                    case .success(nil), .failure: terminal = true
                    }
                    buffers.append(result)
                }
                return true
            }
        }

        func take() -> Result<AVAudioPCMBuffer?, Error>? {
            lock.withLock { buffers.isEmpty ? nil : buffers.removeFirst() }
        }
    }

    private func prepareBeacon(_ description: AdaptiveBeacon, type: SoundType, operation: Operation, ready: LayerReady?) {
        load(description.assets + [description.intro, description.outro].compactMap { $0 }, operation: operation) { [weak self, weak operation] buffers in
            guard let self, let operation else { return }
            guard let firstAsset = description.assets.first, let first = buffers[firstAsset],
                  buffers.values.allSatisfy({ $0.format == first.format }),
                  description.assets.allSatisfy({ buffers[$0]?.frameLength == first.frameLength }),
                  let silence = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: first.frameLength) else {
                self.end(operation, .failed("Incompatible beacon formats or phrase lengths"))
                return
            }
            silence.frameLength = first.frameLength
            for channel in 0..<Int(first.format.channelCount) {
                silence.floatChannelData?[channel].update(repeating: 0, count: Int(silence.frameLength))
            }
            let source = self.attach(type: type, channel: .beacon, format: first.format, operation: operation)
            let beacon = Beacon(description, source: source, buffers: buffers, silence: silence)
            operation.beacon = beacon
            if operation.finishRequested {
                self.finishBeacon(beacon, operation: operation)
            } else {
                if let intro = description.intro.flatMap({ buffers[$0] }), !operation.recovering {
                    source.player.scheduleBuffer(intro)
                } else if beacon.timing.intro > 0, operation.recovering,
                          let silence = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: AVAudioFrameCount(beacon.timing.intro)) {
                    silence.frameLength = silence.frameCapacity
                    for channel in 0..<Int(first.format.channelCount) {
                        silence.floatChannelData?[channel].update(repeating: 0, count: Int(silence.frameLength))
                    }
                    source.player.scheduleBuffer(silence)
                }
                self.updateBeacon(beacon, operation: operation)
            }
            if self.alive(operation) {
                if let ready { ready([source]) } else { self.begin([source], operation: operation) }
            }
        }
    }

    private func playerFrame(_ player: AVAudioPlayerNode) -> Int64? {
        player.lastRenderTime.flatMap { player.playerTime(forNodeTime: $0)?.sampleTime }
    }

    private func updateBeacon(_ beacon: Beacon, operation: Operation) {
        guard !beacon.finishing else { return }
        let heading = heading(for: operation.request.heading)
        let target = beacon.description.select(scene.location, heading, SettingsContext.shared.beaconRingingAngle, operation.focus)
        let source = beacon.source
        source.selectionGain = target?.1 ?? 1
        update(source, operation: operation)
        guard !beacon.hasScheduled || beacon.selected != target?.0 else { return }
        beacon.selected = target?.0
        beacon.hasScheduled = true
        let buffer = target.flatMap { beacon.buffers[$0.0] } ?? beacon.silence
        let next = beacon.timing.next(after: playerFrame(source.player))
        let rate = buffer.format.sampleRate
        var start = next.start
        if next.offset > 0, let tail = buffer.suffix(from: Int(next.offset)) {
            source.player.scheduleBuffer(tail, at: AVAudioTime(sampleTime: start, atRate: rate), options: .interrupts)
            start += Int64(tail.frameLength)
            source.player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: start, atRate: rate), options: .loops)
        } else {
            source.player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: start, atRate: rate), options: [.interrupts, .loops])
        }
    }

    private func finishBeacon(_ beacon: Beacon, operation: Operation) {
        guard !beacon.finishing else { return }
        beacon.finishing = true
        let source = beacon.source
        let frame = beacon.hasScheduled ? beacon.timing.next(after: playerFrame(source.player)).start : 0
        let outro = beacon.description.outro.flatMap { beacon.buffers[$0] }
        let marker = AVAudioPCMBuffer(pcmFormat: beacon.silence.format, frameCapacity: 1)
        marker?.frameLength = 1
        if let marker {
            for channel in 0..<Int(marker.format.channelCount) { marker.floatChannelData?[channel][0] = 0 }
        }
        guard let buffer = outro ?? marker else { end(operation, .failed("Unable to schedule beacon ending")); return }
        schedule(buffer, source: source, operation: operation,
                 at: AVAudioTime(sampleTime: frame, atRate: buffer.format.sampleRate),
                 options: .interrupts) { [weak self, weak operation] in
            guard let self, let operation else { return }
            self.end(operation, .completed)
        }
    }

    private func heading(for source: AudioRequest.HeadingSource) -> Double? {
        switch source {
        case .presentation: return scene.presentation
        case .device: return scene.device
        case .collection: return scene.collection
        }
    }

    private func updateScene() {
        for operation in operations.values {
            operation.sources.forEach { update($0, operation: operation) }
            if let beacon = operation.beacon { updateBeacon(beacon, operation: operation) }
        }
    }

    private func update(_ source: Source, operation: Operation) {
        let settings = SettingsContext.shared
        let volume: Float
        let gain: Float
        switch source.channel {
        case .effects:
            volume = operation.request.usesEffectVolume ? settings.otherVolume : 1
            gain = operation.request.usesEffectVolume ? settings.afxGain : 0
        case .speech: volume = settings.ttsVolume; gain = settings.ttsGain
        case .beacon: volume = settings.beaconVolume; gain = settings.beaconGain
        }
        source.equalizer.globalGain = max(-96, min(24, gain + (source.voiceEQ?.globalGain ?? 0)))
        source.player.volume = volume * source.selectionGain * operation.gain
        guard let environment = source.environment else { return }
        let yaw = scene.yaw
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: Float(yaw), pitch: 0, roll: 0)
        let ring = source.channel == .beacon && heading(for: operation.request.heading) == nil ? 5 : envSettings.envRenderingDistance
        if let position = source.type.position(listener: scene.location, heading: yaw, ring: ring) {
            source.spatialMixer?.position = AVAudio3DPoint(from: position.bearing, distance: position.distance)
        }
    }

    private func observeGraph() {
        if let graphObserver { NotificationCenter.default.removeObserver(graphObserver) }
        graphObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            self?.control.async { [weak self] in
                guard let self, self.wantsRunning, !self.interrupted else { return }
                self.recoverIfStopped()
            }
        }
    }

    private func publish(_ state: State) {
        guard self.state != state else { return }
        self.state = state
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .audioEngineStateChanged, object: self,
                                            userInfo: [Keys.audioEngineStateKey: state.rawValue])
        }
    }

    private func startGraph() -> Bool {
        if engine.isRunning { return true }
        guard wantsRunning, !interrupted, canStart(),
              !sessionManager.needsActivation || sessionManager.activate() else { return false }
        graphMono = isInMonoMode
        publish(.starting)
        _ = engine.mainMixerNode
        do {
            try engine.start()
            publish(.started)
            return true
        } catch {
            GDLogAudioError("Could not start audio graph: \(error)")
            publish(.stopped)
            return false
        }
    }

    private func recoverIfStopped() {
        guard !engine.isRunning, wantsRunning, !interrupted else { return }
        if operations.isEmpty { _ = startGraph() } else { recover() }
    }

    private func recover(replaceGraph: Bool = false) {
        for operation in Array(operations.values) {
            if operation.request.transient || operation.finishRequested {
                end(operation, .interrupted)
            } else {
                reset(operation)
                operation.recovering = true
            }
        }
        stopRecordingOnControl()
        engine.stop()
        if replaceGraph {
            engine = AVAudioEngine()
            observeGraph()
        }
        guard startGraph() else {
            for operation in Array(operations.values) { end(operation, .failed("Audio route recovery failed")) }
            return
        }
        for operation in Array(operations.values) { run(operation) }
    }

    // AudioSessionManager delivers these notifications on the control queue.
    func interruptionBegan() {
        guard !sessionManager.mixWithOthers else { return }
        interrupted = true
        stopRecordingOnControl()
        for operation in Array(operations.values) {
            if operation.request.transient || operation.finishRequested { end(operation, .interrupted) }
            else { reset(operation); operation.recovering = true }
        }
        engine.stop()
        publish(.stopped)
    }

    func interruptionEnded(shouldResume: Bool) {
        guard interrupted, shouldResume || sessionManager.mixWithOthers else { return }
        interrupted = false
        recoverIfStopped()
    }

    func mediaServicesWereReset() {
        interrupted = false
        recover(replaceGraph: true)
    }

    func enableSpeakerMode(_ handler: ((AVAudioSession.PortOverride) -> Void)? = nil) {
        control.async {
            self.routingCallback = handler
            if !self.sessionManager.enableSpeakerMode() { self.routingCallback = nil }
        }
    }

    func disableSpeakerMode(_ handler: ((AVAudioSession.PortOverride) -> Void)? = nil) {
        control.async {
            self.routingCallback = handler
            if !self.sessionManager.disableSpeakerMode() { self.routingCallback = nil }
        }
    }

    func onOutputRouteOverriden(_ override: AVAudioSession.PortOverride) {
        let callback = routingCallback
        routingCallback = nil
        DispatchQueue.main.async { callback?(override) }
    }

    static var recordingDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("AudioRecordings")
    }

    var isRecording: Bool { statusLock.withLock { status.recording } }

    func startRecording() {
        control.async {
            guard self.recordingFile == nil, self.startGraph(), let directory = Self.recordingDirectory else { return }
            let mixer = self.engine.mainMixerNode
            let format = mixer.outputFormat(forBus: 0)
            var output = AudioStreamBasicDescription(mSampleRate: format.sampleRate, mFormatID: kAudioFormatMPEG4AAC,
                                                      mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0,
                                                      mBytesPerFrame: 0, mChannelsPerFrame: format.channelCount,
                                                      mBitsPerChannel: 0, mReserved: 0)
            var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            guard AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &formatSize, &output) == noErr else { return }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(ISO8601DateFormatter().string(from: Date())).appendingPathExtension("m4a")
                var outputFile: ExtAudioFileRef?
                guard ExtAudioFileCreateWithURL(url as CFURL, kAudioFileM4AType, &output, nil,
                                                AudioFileFlags.eraseFile.rawValue, &outputFile) == noErr,
                      let file = outputFile else { return }
                var input = format.streamDescription.pointee
                // Prime AudioToolbox’s asynchronous writer before the first audio callback.
                guard ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, formatSize, &input) == noErr,
                      ExtAudioFileWriteAsync(file, 0, nil) == noErr else {
                    ExtAudioFileDispose(file)
                    return
                }
                mixer.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
                    ExtAudioFileWriteAsync(file, buffer.frameLength, buffer.audioBufferList)
                }
                self.recordingFile = file
                self.statusLock.withLock { self.status.recording = true }
            } catch { GDLogAudioError("Could not start audio recording: \(error)") }
        }
    }

    func stopRecording() { control.async { self.stopRecordingOnControl() } }

    private func stopRecordingOnControl() {
        guard let file = recordingFile else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        recordingFile = nil
        statusLock.withLock { status.recording = false }
        ExtAudioFileDispose(file)
    }
}

private extension AVAudioPCMBuffer {
    func suffix(from offset: Int) -> AVAudioPCMBuffer? {
        guard offset >= 0, offset < Int(frameLength),
              let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength - AVAudioFrameCount(offset)),
              let input = floatChannelData, let output = result.floatChannelData else { return nil }
        result.frameLength = result.frameCapacity
        for channel in 0..<Int(format.channelCount) {
            output[channel].update(from: input[channel].advanced(by: offset), count: Int(result.frameLength))
        }
        return result
    }
}
