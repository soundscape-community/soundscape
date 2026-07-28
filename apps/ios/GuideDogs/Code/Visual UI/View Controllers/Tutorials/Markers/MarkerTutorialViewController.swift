//
//  MarkerTutorialViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import AVFoundation
import CoreLocation
import SwiftUI

// TODO: handle other audio during tutorial
class MarkerTutorialViewController: BaseTutorialViewController {
    
    // MARK: Types
    
    private struct MarkerTutorialPage {
        let title: String
        let image: UIImage
        let text: String
        let buttonTitle: String?
        let action: MarkerTutorialAction?
    }
    
    private struct PageIndexes {
        static let intro = 0
        static let addMarker = 1
        static let editMarker = 2
        static let nearbyMarkers = 3
        static let audioBeacon = 4
    }
    
    // MARK: Properties

    private let tutorial = [
        // Intro
        MarkerTutorialPage(title: GDLocalizedString("tutorial.markers.getting_started"),
                           image: UIImage(named: "Markers tutorial - 01")!,
                           text: GDLocalizedString("tutorial.markers.text.Intro"),
                           buttonTitle: GDLocalizedString("tutorial.markers.add_marker"),
                           action: .addMarker),
        
        // Edit Marker
        MarkerTutorialPage(title: GDLocalizedString("tutorial.markers.mark_your_world"),
                           image: UIImage(named: "Markers tutorial - 02")!,
                           text: GDLocalizedString("tutorial.markers.text.EditMarker"),
                           buttonTitle: nil,
                           action: nil),
        MarkerTutorialPage(title: GDLocalizedString("tutorial.markers.mark_your_world"),
                           image: UIImage(named: "Markers tutorial - 02")!,
                           text: GDLocalizationUnnecessary("placeholder_page_for_select_marker_screen"),
                           buttonTitle: nil,
                           action: nil),

        // Nearby Markers
        MarkerTutorialPage(title: GDLocalizedString("tutorial.markers.experience_your_world"),
                           image: UIImage(named: "Markers tutorial - 04")!,
                           text: GDLocalizedString("tutorial.markers.text.NearbyMarkers"),
                           buttonTitle: GDLocalizedString("callouts.nearby_markers"),
                           action: .nearbyMarkers),
        
        // Audio Beacon
        MarkerTutorialPage(title: GDLocalizedString("tutorial.markers.experience_your_world"),
                           image: UIImage(named: "Markers tutorial - 04")!,
                           text: GDLocalizedString("tutorial.markers.text.AudioBeacon"),
                           buttonTitle: nil,
                           action: nil),
        
        // Wrap Up
        MarkerTutorialPage(title: GDLocalizedString("tutorial.markers.experience_your_world"),
                           image: UIImage(named: "Markers tutorial - 05")!,
                           text: GDLocalizedString("tutorial.markers.text.WrapUp"),
                           buttonTitle: nil,
                           action: nil)
    ]
    
    // These page indexes represents pages that text should be delayed to accommodate VoiceOver callouts
    private var pageIndexesForVoiceOverDelayedPlay: [Int] {
        return [PageIndexes.addMarker,
                PageIndexes.nearbyMarkers,
                PageIndexes.audioBeacon]
    }
    
    private var selectedPOI: POI?
    private var referenceEntity: ReferenceEntity? {
        guard let selectedPOI = selectedPOI else { return nil }
        return SpatialDataCache.referenceEntityByEntityKey(selectedPOI.key)
    }
    
    var player: FadeableAudioPlayer?
    private var presentedAlertController: UIAlertController?
    private let viewState = MarkerTutorialViewState(exitTitle: GDLocalizedString("tutorial.skip"))
    private var hostingController: UIHostingController<MarkerTutorialView>?
    
    // Tutorial state properties
    
    private var started = false
    private var currentPageIndex: UInt?
    
    private var markerAdded = false
    private var markerEdited = false
    private var pressedNearbyMarkers = false
    private var didSetAudioBeacon = false

    /// Used for telemetry to identify the context (source) of the viewing this screen
    private(set) var logContext: String?

    // MARK: Initialization

    init(logContext: String? = nil) {
        self.logContext = logContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: Lifecycle

    override func loadView() {
        let rootView = MarkerTutorialView(
            state: viewState,
            onAction: { [weak self] action in
                self?.perform(action)
            },
            onExit: { [weak self] in
                self?.tryExitTutorial()
            }
        )
        let hostingController = UIHostingController(rootView: rootView)

        addChild(hostingController)
        view = UIView()
        view.backgroundColor = UIColor(red: 36.0 / 255.0,
                                       green: 58.0 / 255.0,
                                       blue: 102.0 / 255.0,
                                       alpha: 1)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
        
        AppContext.shared.isInTutorialMode = true
        
        setupAudioPlayer(with: "tutorial_background_music")
        
        toggleAppCalloutsOff()
        clearView()
        started = true
        
        GDATelemetry.trackScreenView("tutorial.markers", with: logContext == nil ? nil : ["context": logContext!])
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AppContext.shared.audioEngine.session)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: true)

        showNextPage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        stopMusic()
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        // Remove reference to `presentedAlertController`
        presentedAlertController = nil
        
        super.dismiss(animated: true, completion: completion)
    }
    
    // MARK: Audio Player
    
    @objc func handleAudioSessionInterruption(_ notification: NSNotification) {
        exitTutorial(finished: false)
    }

    private func setupAudioPlayer(with filename: String) {
        guard let player = FadeableAudioPlayer.fadeablePlayer(with: filename, fileTypeHint: AVFileType.mp3.rawValue) else {
            GDLogAppError("Marker tutorial: audio error: file not found.")
            return
        }
        
        player.numberOfLoops = -1 // play indefinitely
        self.player = player
    }
    
    private func playMusic() {
        guard let player = player, !player.isPlaying else {
            return
        }
        
        player.fadeIn(to: 0.1, duration: 1.5)
    }

    private func stopMusic() {
         player?.fadeOut(nil)
    }
    
    // MARK: Parent Override
    
    override internal func play(delay: TimeInterval = 0.0, text: String, _ completion: ((Bool) -> Void)? = nil) {
        let markerName = referenceEntity?.name ?? selectedPOI?.localizedName ?? GDLocalizedString("tutorial.markers.your_marker")
        let textToPlay = text.replacingOccurrences(of: "@!marker_name!!", with: markerName)

        super.play(delay: delay, text: textToPlay, completion)
    }
    
    override func stop() {
        started = false
        
        toggleAppCalloutsOn()

        super.stop()
    }

    override internal func updatePageText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard self?.viewState.text != text else {
                return
            }

            self?.viewState.updateText(text)
        }
    }
    
    // MARK: Tutorial Flow

    private func showNextPage() {
        guard !hasFinishedTutorial() else {
            exitTutorial(finished: true)
            return
        }
        
        guard canContinueToNextPage() else {
            return
        }
        
        let index = (currentPageIndex == nil) ? 0 : currentPageIndex! + 1
        showPage(with: index)
    }
    
    private func showPage(with index: UInt) {
        guard index < tutorial.count else {
            return
        }
        
        currentPageIndex = index
        
        show(page: tutorial[Int(index)])
    }
    
    private func show(page: MarkerTutorialPage) {
        if currentPageIndex! == PageIndexes.editMarker {
            editMarkerAction()
            return
        }
        
        DispatchQueue.main.async {
            self.viewState.show(title: page.title,
                                image: page.image,
                                text: nil,
                                actionTitle: page.buttonTitle,
                                action: page.action,
                                hidesContentFromAccessibility: self.currentPageIndex != UInt(PageIndexes.intro))
        }

        if page.buttonTitle == nil {
            UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
        } else if currentPageIndex! == PageIndexes.intro {
            // Clear destination if needed
            try? AppContext.shared.spatialDataContext.destinationManager.clearDestination(logContext: "tutorial.markers.start_tutorial")
            
            // Hush speech or beacon if playing
            AppContext.shared.eventProcessor.hush(playSound: false)
            
            DispatchQueue.main.async { [weak self] in
                self?.viewState.revealAction()
                UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
            }
        }
        
        guard let currentPageIndex = currentPageIndex, currentPageIndex > 0 else {
            updatePageText(page.text)
            return
        }
        
        playMusic()

        let pageIndexBeforeTextPlay = self.currentPageIndex

        // We need to delay text play to accomodate VoiceOver finishing it's output of the screen's UI object when navigating to this page
        let shouldDelayTextPlay = UIAccessibility.isVoiceOverRunning && pageIndexesForVoiceOverDelayedPlay.contains(Int(currentPageIndex))
        if shouldDelayTextPlay {
            // Clear current text before delay
            self.viewState.updateText(nil)
        }
        
        play(delay: shouldDelayTextPlay ? 1.5 : 0.0, text: page.text) { [weak self] (_) in
            guard let `self` = self else { return }
            guard !self.pageFinished else { return }
            
            // Check that we have not progressed to next pages since the initialization of this block
            if let pageIndexBeforeTextPlay = pageIndexBeforeTextPlay,
                let currentPageIndex = self.currentPageIndex, currentPageIndex > pageIndexBeforeTextPlay {
                return
            }
            
            guard self.currentPageIndex! != PageIndexes.audioBeacon else {
                self.setAudioBeacon()
                return
            }
            
            if page.buttonTitle == nil {
                self.showNextPage()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.viewState.revealAction()
                    UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
                }
            }
        }
    }
    
    private func canContinueToNextPage() -> Bool {
        guard started else {
            return false
        }
        
        guard let currentPageIndex = currentPageIndex else { return true }
        
        if currentPageIndex == PageIndexes.intro && !markerAdded {
            return false
        }
        
        if currentPageIndex == PageIndexes.nearbyMarkers && !pressedNearbyMarkers {
            return false
        }
        
        if currentPageIndex == PageIndexes.audioBeacon && !didSetAudioBeacon {
            return false
        }
        
        return true
    }

    private func hasFinishedTutorial() -> Bool {
        guard let currentPageIndex = currentPageIndex else { return false }
        return currentPageIndex == tutorial.count - 1
    }
    
    // MARK: UI Actions

    private func perform(_ action: MarkerTutorialAction) {
        switch action {
        case .addMarker:
            addMarkerAction()
        case .nearbyMarkers:
            nearbyMarkersAction()
        }
    }

    private func addMarkerAction() {
        GDATelemetry.track("tutorial.markers.add_marker")

        let storyboard = UIStoryboard(name: "POITable", bundle: .main)
        guard let viewController = storyboard.instantiateInitialViewController() as? SearchTableViewController else {
            GDLogAppError("Marker tutorial: unable to load POI table.")
            return
        }

        viewController.delegate = self
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func editMarkerAction() {
        let detail: LocationDetail
            
        if let referenceEntity = referenceEntity {
            detail = LocationDetail(marker: referenceEntity)
        } else {
            detail = LocationDetail(entity: selectedPOI!)
        }
        
        let config = EditMarkerConfig(detail: detail,
                                      route: nil,
                                      context: "marker_tutorial",
                                      addOrUpdateAction: .popToViewController(type: MarkerTutorialViewController.self),
                                      deleteAction: nil,
                                      leftBarButtonItemIsHidden: true)
        
        if let vc = MarkerEditViewRepresentable(config: config).makeViewController() {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func nearbyMarkersAction() {
        guard !pressedNearbyMarkers else {
            return
        }
        
        pressedNearbyMarkers = true
        
        stopMusic()
        
        let entityKeyToInclude = selectedPOI?.key != nil ? [selectedPOI!.key] : []
        let event = ExplorationModeToggled(.nearbyMarkers, requiredMarkerKeys: entityKeyToInclude, logContext: "marker_tutorial") { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.showNextPage()
            }
        }
        
        AppContext.process(event)
    }
    
    private func presentExitAlert() {
        let alert = UIAlertController(title: GDLocalizedString("tutorial.exit.alert_title"),
                                      message: nil,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.exit"), style: .destructive, handler: { (_) in
            self.exitTutorial()
        }))
        
        self.present(alert, animated: true, completion: nil)
        
        // Save reference to alert
        presentedAlertController = alert
    }
    
    private func tryExitTutorial() {
        if currentPageIndex == UInt(PageIndexes.intro) {
            // Do not present alert if user is on the intro page
            exitTutorial()
        } else {
            // Present alert before exiting
            presentExitAlert()
        }
    }
    
    private func exitTutorial(finished: Bool = false) {
        // If we are already presenting an alert, dismiss it
        if let presentedAlertController = presentedAlertController,
            isPresentingAlert(presentedAlertController: presentedAlertController) {
            dismiss(animated: true)
        }
        
        self.pageFinished = true
        self.stop()
        FirstUseExperience.setDidComplete(for: .markerTutorial)
        AppContext.shared.isInTutorialMode = false

        GDATelemetry.track("tutorial.markers." + (finished ? "finished" : "exit"))
        
        if finished {
            GDATelemetry.helper?.tutorialMarkerStatus = "finished"
            GDATelemetry.helper?.tutorialMarkerCount += 1
        } else if GDATelemetry.helper?.tutorialMarkerStatus != "finished" {
            GDATelemetry.helper?.tutorialMarkerStatus = "exited"
        }
        
        NotificationCenter.default.removeObserver(self,
                                                  name: AVAudioSession.interruptionNotification,
                                                  object: AppContext.shared.audioEngine.session)
        
        if self.navigationController?.presentingViewController != nil {
            self.dismiss(animated: true, completion: nil)
        } else if let nav = navigationController, let index = nav.viewControllers.firstIndex(of: self), index > 0 {
            // Pop to the parent of the tutorial
            nav.popToViewController(nav.viewControllers[index - 1], animated: true)
        }
    }
    
    private func clearView() {
        viewState.clear()
    }
    
    // MARK: Audio Beacon
    
    private func setAudioBeacon() {
        guard let entityKey = referenceEntity?.entityKey else { return }
        guard let manager = AppContext.shared.spatialDataContext.destinationManager as? DestinationManager else { return }
        
        player?.fadeOut({
            _ = try? manager.setDestination(entityKey: entityKey, enableAudio: true, userLocation: AppContext.shared.geolocationManager.location, estimatedAddress: nil, logContext: "tutorial.markers")
            
            // If a user is inside the selected marker, the audio will not turn on.
            if !manager.isAudioEnabled {
                manager.toggleDestinationAudio()
            }
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.beaconInBounds), name: NSNotification.Name.beaconInBoundsDidChange, object: nil)
        })
    }
    
    @objc func beaconInBounds(_ notification: Notification) {
        guard let isBeaconInBounds = notification.userInfo?[DestinationManager.Keys.isBeaconInBounds] as? Bool else {
            return
        }
        
        // Wait for the beacon to be in range
        guard isBeaconInBounds else {
            return
        }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.beaconInBoundsDidChange, object: nil)
        
        // Allow the "ting" sound to play for a few seconds, and then continue the next page
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            try? AppContext.shared.spatialDataContext.destinationManager.clearDestination(logContext: "tutorial.markers.clear_test_beacon")
            
            self?.didSetAudioBeacon = true
            self?.showNextPage()
        }
    }
    
}

// MARK: POITableViewDelegate

extension MarkerTutorialViewController: POITableViewDelegate {
    var allowCurrentLocation: Bool {
        return false
    }
    
    var allowMarkers: Bool {
        return false
    }
    
    var poiAccessibilityHint: String {
        return GDLocalizedString("tutorial.markers.mark_location.acc_hint")
    }
    
    var usageLog: String {
        return "tutorial.markers"
    }
    
    var doneNavigationItem: Bool {
        return false
    }
    
    func didSelect(poi: POI) {
        // For the "Add Marker" Page
        if selectedPOI == nil {
            selectedPOI = poi
            markerAdded = true
        }

        navigationController?.popToViewController(self, animated: true)
    }
    
    func didSelect(currentLocation location: CLLocation) {
        // Unused
    }
    
    var isCachingRequired: Bool {
        // Only locations with an unencumbered coordinate can be cached and
        // saved as a marker
        return true
    }
}
