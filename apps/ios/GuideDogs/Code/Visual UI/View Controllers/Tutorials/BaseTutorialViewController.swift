//
//  BaseTutorialViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

// MARK: Types

struct Tutorial {
    let pages: [Page]
}

struct Page {
    let title: String
    let image: UIImage
    let text: String
    let buttonTitle: String?
    let buttonAction: Selector?
}

// MARK: - Notification Names

extension Notification.Name {
    static let disableMagicTap = Notification.Name("GDADisableMagicTap")
    static let enableMagicTap = Notification.Name("GDAEnableMagicTap")
}

// MARK: -

class BaseTutorialViewController: UIViewController {

    // MARK: Properties
    
    @IBOutlet weak var pageTextLabel: UILabel!
    
    var pageFinished = false
    internal let tutorialCalloutPlayer = TutorialCalloutPlayer()
    
    // MARK: Playing Content

    internal func play(delay: TimeInterval = 0.0, text: String, _ completion: ((Bool) -> Void)? = nil) {
        Task { @MainActor [weak self] in
            guard let self = self else {
                completion?(false)
                return
            }

            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
            }

            guard !self.pageFinished else {
                completion?(false)
                return
            }

            self.updatePageText(text)
            let finished = await self.tutorialCalloutPlayer.play(text: text)
            completion?(finished)
        }
    }
    
    internal func playRepeated(_ text: String, _ delay: TimeInterval, _ shouldCancel: @escaping () -> Bool, _ completion: ((Bool) -> Void)? = nil) {
        // Only schedule the repeat if the cancelation condition is not already met
        guard !shouldCancel() else {
            return
        }
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // Only repeat the instructions if the cancelation condition is still not met
            guard !shouldCancel() else {
                return
            }
            self?.play(text: text) { finished in
                completion?(finished)
                self?.playRepeated(text, delay, shouldCancel, completion)
            }
        }
    }
    
    internal func stop() {
        UIRuntimeProviderRegistry.providers.uiHushEventProcessor(playSound: false)
    }
    
    internal func updatePageText(_ text: String) {
        guard pageTextLabel.text != text else {
            return
        }
        
        let animations: (() -> Void) = { [weak self] in
            self?.pageTextLabel.text = text
        }
        
        UIView.transition(with: pageTextLabel, duration: 0.50, options: .transitionCrossDissolve, animations: animations, completion: nil)
    }
    
    // MARK: Handle other app audio
    
    internal func toggleAppCalloutsOn() {
        if !SettingsContext.shared.automaticCalloutsEnabled {
            UIRuntimeProviderRegistry.providers.uiProcessEvent(ToggleAutoCalloutsEvent(playSound: false))
        }
    }
    
    internal func toggleAppCalloutsOff() {
        if SettingsContext.shared.automaticCalloutsEnabled {
            UIRuntimeProviderRegistry.providers.uiProcessEvent(ToggleAutoCalloutsEvent(playSound: false))
        }
    }
    
    // MARK: Accessibility

    override func accessibilityPerformMagicTap() -> Bool {
        // Intercept magic taps by default
        return true
    }
    
}
