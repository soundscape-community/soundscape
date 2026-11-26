//
//  DestinationTutorialIntroViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import CoreLocation
import UIKit

class DestinationTutorialIntroViewController: DestinationTutorialPage {
    weak var source: UIViewController?
    var onFinish: (() -> Void)?
    private(set) var logContext: String?
    var entityKey: String?

    private let music = TutorialMusic()
    var backgroundVolume: Float = 0.1
    var fadeInDuration: TimeInterval = 1.5

    init(source: UIViewController?, logContext: String? = nil) {
        self.source = source
        self.logContext = logContext
        super.init(title: GDLocalizedString("tutorial.beacon.getting_started"),
                   imageName: "destination_graphic01",
                   text: GDLocalizedString("tutorial.beacon.getting_started.text"),
                   actionTitle: GDLocalizedString("location_detail.action.beacon"),
                   action: .setBeacon)
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("DestinationTutorialIntroViewController must be created programmatically")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AppContext.shared.audioEngine.session)
    }

    @objc private func handleAudioSessionInterruption(_ notification: NSNotification) {
        exitTutorial()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppContext.shared.isInTutorialMode = true
        try? AppContext.shared.spatialDataContext.destinationManager.clearDestination(logContext: "tutorial.beacon.start_tutorial")
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        pauseBackgroundTrack(nil)
    }

    override func perform(_ action: DestinationTutorialAction) {
        guard action == .setBeacon else { return }

        let picker = SearchTableViewController()
        picker.delegate = self
        navigationController?.pushViewController(picker, animated: true)
    }

    override func exitPage() {
        exitTutorial()
    }

    @objc func exitTutorial() {
        if GDATelemetry.helper?.tutorialBeaconStatus != "finished" {
            GDATelemetry.helper?.tutorialBeaconStatus = "exited"
        }
        tutorialComplete()
    }

    private func finishNavigation() {
        FirstUseExperience.setDidComplete(for: .beaconTutorial)
        if let onFinish {
            onFinish()
        } else if navigationController?.presentingViewController != nil {
            dismiss(animated: true)
        } else if let source = source {
            navigationController?.popToViewController(source, animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
        AppContext.shared.isInTutorialMode = false
    }
}

extension DestinationTutorialIntroViewController: DestinationTutorialPageDelegate {
    func getEntityKey() -> String? { entityKey }
    func pauseBackgroundTrack(_ completion: (() -> Void)?) { music.stop(completion) }
    func resumeBackgroundTrack() { music.start(volume: backgroundVolume, duration: fadeInDuration) }

    func pageComplete() {
        let tutorial = DestinationTutorialViewController(source: source, entityKey: entityKey)
        tutorial.onFinish = onFinish
        guard let navigationController = navigationController else { return }
        var controllers = navigationController.viewControllers
        if controllers.last !== self {
            controllers.removeLast()
        }
        controllers.append(tutorial)
        navigationController.setViewControllers(controllers, animated: true)
    }

    func tutorialComplete() { finishNavigation() }
}

extension DestinationTutorialIntroViewController: POITableViewDelegate {
    var poiAccessibilityHint: String { GDLocalizedString("tutorial.beacon.mark_location.acc_hint") }
    var allowCurrentLocation: Bool { false }
    var allowMarkers: Bool { false }
    var usageLog: String { "tutorial.beacon" }
    var doneNavigationItem: Bool { false }
    var isCachingRequired: Bool { false }

    func didSelect(poi: POI) {
        do {
            entityKey = try AppContext.shared.spatialDataContext.destinationManager.setDestination(
                entityKey: poi.key,
                enableAudio: false,
                userLocation: AppContext.shared.geolocationManager.location,
                estimatedAddress: nil,
                logContext: "tutorial.beacon"
            )
        } catch {
            GDLogAppError("Unable to set destination in Destination tutorial")
        }
        pageComplete()
    }

    func didSelect(currentLocation location: CLLocation) {
        fatalError("The current location option should be disabled for this view controller!")
    }
}

@MainActor
final class TutorialMusic {
    private var handle: PlaybackHandle?

    func start(volume: Float, duration: TimeInterval) {
        guard handle == nil else { return }
        let sound = AssetSound(asset: .catalog(name: "tutorial_background_music", extension: "mp3"))
        let playback = AppContext.shared.audioEngine.play(AudioRequest(sounds: [sound], loops: true,
                                                                        transient: false, initialGain: 0, usesEffectVolume: false))
        handle = playback
        playback.fade(to: volume, seconds: duration)
        Task { [weak self] in
            _ = await playback.completion()
            if self?.handle == playback { self?.handle = nil }
        }
    }

    func stop(_ completion: (() -> Void)? = nil) {
        guard let playback = handle else { completion?(); return }
        handle = nil
        playback.fade(to: 0, seconds: 1, stop: true)
        if let completion {
            Task {
                _ = await playback.completion()
                completion()
            }
        }
    }

    deinit { handle?.stop() }
}
