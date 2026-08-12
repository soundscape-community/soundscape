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
    private(set) var logContext: String?
    var entityKey: String?

    var player: FadeableAudioPlayer?
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

        GDATelemetry.trackScreenView("tutorial.beacons", with: logContext.map { ["context": $0] })
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

        guard player == nil,
              let player = FadeableAudioPlayer.fadeablePlayer(with: "tutorial_background_music",
                                                               fileTypeHint: AVFileType.mp3.rawValue) else {
            return
        }
        player.numberOfLoops = -1
        self.player = player
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        pauseBackgroundTrack(nil)
    }

    override func perform(_ action: DestinationTutorialAction) {
        guard action == .setBeacon else { return }

        let storyboard = UIStoryboard(name: "POITable", bundle: .main)
        guard let picker = storyboard.instantiateInitialViewController() as? SearchTableViewController else {
            GDLogAppError("Destination tutorial: unable to load POI table.")
            return
        }
        picker.delegate = self
        GDATelemetry.track("tutorial.beacon.set_beacon")
        navigationController?.pushViewController(picker, animated: true)
    }

    override func exitPage() {
        exitTutorial()
    }

    @objc func exitTutorial() {
        GDATelemetry.track("tutorial.beacon.exit")
        if GDATelemetry.helper?.tutorialBeaconStatus != "finished" {
            GDATelemetry.helper?.tutorialBeaconStatus = "exited"
        }
        tutorialComplete()
    }

    private func finishNavigation() {
        FirstUseExperience.setDidComplete(for: .beaconTutorial)
        if navigationController?.presentingViewController != nil {
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
    func pauseBackgroundTrack(_ completion: (() -> Void)?) { player?.fadeOut(completion) }
    func resumeBackgroundTrack() { player?.fadeIn(to: backgroundVolume, duration: fadeInDuration) }

    func pageComplete() {
        let tutorial = DestinationTutorialViewController(source: source, entityKey: entityKey)
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
