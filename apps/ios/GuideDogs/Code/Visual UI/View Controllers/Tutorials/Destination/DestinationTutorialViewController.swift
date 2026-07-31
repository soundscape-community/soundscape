//
//  DestinationTutorialViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import UIKit

class DestinationTutorialViewController: UIViewController, AVAudioPlayerDelegate {
    private(set) var steps: [DestinationTutorialPage] = []
    private(set) var currentPageIndex = 0
    private var presentedAlertController: UIAlertController?
    private var currentPage: DestinationTutorialPage?
    private var didDisableCallouts = false

    var player: FadeableAudioPlayer?
    var backgroundVolume: Float = 0.1
    var fadeInDuration: TimeInterval = 1.5
    var entityKey: String?
    weak var source: UIViewController?

    init(source: UIViewController?, entityKey: String?) {
        self.source = source
        self.entityKey = entityKey
        super.init(nibName: nil, bundle: nil)
        steps = [DestinationTutorialBeaconPage(),
                 DestinationTutorialInfoPage(),
                 DestinationTutorialMutePage()]
        for page in steps {
            page.delegate = self
        }
    }

    required init?(coder: NSCoder) {
        fatalError("DestinationTutorialViewController must be created programmatically")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.Background.tutorial
        showPage(at: 0, animated: false)

        guard let player = FadeableAudioPlayer.fadeablePlayer(with: "tutorial_background_music",
                                                               fileTypeHint: AVFileType.mp3.rawValue) else {
            GDLogAppError("Destination tutorial error: file not found.")
            return
        }
        player.numberOfLoops = -1
        player.delegate = self
        self.player = player

        NotificationCenter.default.post(name: .disableMagicTap, object: self)
        NotificationCenter.default.post(name: .disableDestinationGeofence, object: self)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AppContext.shared.audioEngine.session)
    }

    @objc private func handleAudioSessionInterruption(_ notification: NSNotification) {
        tutorialComplete()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppContext.shared.isInTutorialMode = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        player?.fadeIn(to: backgroundVolume, duration: fadeInDuration)
        if SettingsContext.shared.automaticCalloutsEnabled {
            didDisableCallouts = true
            AppContext.process(ToggleAutoCalloutsEvent(playSound: false))
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        cleanupTutorialState()
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedAlertController = nil
        super.dismiss(animated: flag, completion: completion)
    }

    @discardableResult
    func goToNextPage() -> Bool {
        guard currentPageIndex + 1 < steps.count else { return false }
        currentPageIndex += 1
        showPage(at: currentPageIndex, animated: view.window != nil)
        return true
    }

    private func showPage(at index: Int, animated: Bool) {
        let next = steps[index]
        let previous = currentPage
        addChild(next)
        next.view.frame = view.bounds
        next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let install = {
            previous?.willMove(toParent: nil)
            previous?.view.removeFromSuperview()
            previous?.removeFromParent()
            self.view.addSubview(next.view)
            next.didMove(toParent: self)
            self.currentPage = next
        }

        guard animated, let previous = previous else {
            install()
            return
        }
        previous.willMove(toParent: nil)
        transition(from: previous, to: next, duration: 0.3, options: .transitionCrossDissolve) {
            previous.removeFromParent()
            next.didMove(toParent: self)
            self.currentPage = next
        }
    }

    func exitTutorial() {
        let alert = UIAlertController(title: GDLocalizedString("tutorial.exit.alert_title"),
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.exit"), style: .destructive) { [weak self] _ in
            self?.finish(finished: false)
        })
        present(alert, animated: true)
        presentedAlertController = alert
    }

    private func finish(finished: Bool) {
        steps.forEach { $0.pageFinished = true }
        NotificationCenter.default.removeObserver(self,
                                                  name: AVAudioSession.interruptionNotification,
                                                  object: AppContext.shared.audioEngine.session)
        FirstUseExperience.setDidComplete(for: .beaconTutorial)
        AppContext.shared.isInTutorialMode = false

        if finished {
            GDATelemetry.track("tutorial.beacon.finished")
            GDATelemetry.helper?.tutorialBeaconStatus = "finished"
            GDATelemetry.helper?.tutorialBeaconCount += 1
        } else {
            GDATelemetry.track("tutorial.beacon.exit")
            if GDATelemetry.helper?.tutorialBeaconStatus != "finished" {
                GDATelemetry.helper?.tutorialBeaconStatus = "exited"
            }
        }

        if navigationController?.presentingViewController != nil {
            dismiss(animated: true)
        } else if let source = source {
            navigationController?.popToViewController(source, animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func cleanupTutorialState() {
        player?.fadeOut { [weak self] in self?.player = nil }
        NotificationCenter.default.post(name: .enableMagicTap, object: self)
        NotificationCenter.default.post(name: .enableDestinationGeofence, object: self)
        AppContext.shared.eventProcessor.hush(playSound: false)

        if didDisableCallouts, !SettingsContext.shared.automaticCalloutsEnabled {
            AppContext.process(ToggleAutoCalloutsEvent(playSound: false))
        }
        didDisableCallouts = false

        if AppContext.shared.spatialDataContext.destinationManager.isDestinationSet {
            try? AppContext.shared.spatialDataContext.destinationManager.clearDestination(logContext: "tutorial.beacon.clear_test_beacon")
        }
    }
}

extension DestinationTutorialViewController: DestinationTutorialPageDelegate {
    func getEntityKey() -> String? { entityKey }
    func pauseBackgroundTrack(_ completion: (() -> Void)?) { player?.fadeOut(completion) }
    func resumeBackgroundTrack() { player?.fadeIn(to: backgroundVolume, duration: fadeInDuration) }
    func pageComplete() { _ = goToNextPage() }
    func tutorialComplete() { finish(finished: true) }
}
