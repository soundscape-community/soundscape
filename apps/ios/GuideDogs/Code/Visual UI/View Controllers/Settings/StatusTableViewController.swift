//
//  StatusTableViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import SwiftUI
import CocoaLumberjackSwift

class TroubleshootingViewController: UIViewController {
    private let model = TroubleshootingModel()
    private var reenableCalloutsAfterReload = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = GDLocalizedString("settings.section.troubleshooting")
        let host = UIHostingController(rootView: TroubleshootingScreen(
            model: model,
            checkAudio: { [weak self] in self?.crosscheckTouchUpInside() },
            configureServer: { [weak self] in self?.urlTouchUpInside() },
            clearCache: { [weak self] in self?.clearCacheTouchUpInside() },
            deleteUserData: { [weak self] in self?.deleteUserDataTouchUpInside() }
        ))
        add(host) { content in
            [
                content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            NotificationCenter.default.removeObserver(self, name: .spatialDataStateChanged, object: nil)
        }
    }

    @objc func urlTouchUpInside() {
        let alertController = UIAlertController(title: GDLocalizedString("troubleshooting.tile_server_url"), message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = SettingsContext.shared.servicesHostName
        }
        
        let submitAction = UIAlertAction(title: GDLocalizedString("general.alert.done"), style: .default) { [unowned alertController] _ in
            if let textField = alertController.textFields?.first {
                if let userInput = textField.text, !userInput.isEmpty {
                    SettingsContext.shared.servicesHostName = userInput
                    // Update url button label
                    self.model.server = SettingsContext.shared.servicesHostName
                }
            }
        }
        
        let resetAction = UIAlertAction(title: GDLocalizedString("general.alert.reset"), style: .destructive) { [] _ in
            // reset SettingsContext.shared.servicesHostName to default value
            SettingsContext.shared.servicesHostName = ""
            // Update url button label
            self.model.server = SettingsContext.shared.servicesHostName
        }
        
        let cancelAction = UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel)
        
        alertController.addAction(submitAction)
        alertController.addAction(resetAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    @objc func crosscheckTouchUpInside() {
        GDLogAppInfo("Play crosscheck audio")
        AppContext.process(CheckAudioEvent())
    }
    
    @objc func clearCacheTouchUpInside() {
        // Only allow the cache to be deleted if we have a network connection to reload the cache
        guard AppContext.shared.offlineContext.state != .offline else {
            let alert = UIAlertController(title: GDLocalizedString("general.error.network_connection_required"),
                                          message: GDLocalizedString("general.error.network_connection_required.deleting_data"),
                                          preferredStyle: UIAlertController.Style.alert)
            
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .cancel, handler: nil))
            
            present(alert, animated: true, completion: nil)
            
            return
        }
        
        let alert = UIAlertController(title: GDLocalizedString("settings.clear_cache.alert_title"),
                                      message: GDLocalizedString("settings.clear_cache.alert_message"),
                                      preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.delete"), style: .destructive, handler: { _ in
            AppContext.shared.eventProcessor.hush(playSound: false)
            
            if SettingsContext.shared.automaticCalloutsEnabled {
                self.reenableCalloutsAfterReload = true
                SettingsContext.shared.automaticCalloutsEnabled = false
            }    
            self.presentLoadingModal()
            
            // Check that tiles can be downloaded before we attempt to delete the cache
            AppContext.shared.spatialDataContext.checkServiceConnection { [weak self] (success) in
                guard success else {
                    DispatchQueue.main.async { self?.displayUnableToClearCacheWarning() }
                    return
                }
                
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    if !AppContext.shared.spatialDataContext.clearCache() {
                        DispatchQueue.main.async { self?.displayUnableToClearCacheWarning() }
                    }
                }
            }
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc func deleteUserDataTouchUpInside() {
        let alert = UIAlertController(title: GDLocalizedString("settings.clear_cache.markers.alert_title"),
                                      message: GDLocalizedString("general.alert.destructive_undone_message"),
                                      preferredStyle: UIAlertController.Style.actionSheet)
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: { [weak self] _ in
            if self?.reenableCalloutsAfterReload ?? false {
                SettingsContext.shared.automaticCalloutsEnabled = true
            }
        }))
        
        alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.delete"), style: .destructive) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await ReferenceEntity.eraseUserData()
                } catch {
                    GDLogAppError("Unable to delete saved markers and routes: \(error)")
                    let warning = UIAlertController(title: GDLocalizedString("general.alert.error.message"),
                                                    message: nil, preferredStyle: .alert)
                    warning.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .cancel))
                    self?.present(warning, animated: true)
                }
            }
        })

        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(alert, animated: true, completion: nil)
    }
    
    private func presentLoadingModal() {
        let viewController = UIHostingController(rootView: LoadingModalView(message: GDLocalizedString("text.cleaning_things")))
        viewController.view.backgroundColor = .clear
        viewController.modalPresentationStyle = .overCurrentContext
        viewController.modalTransitionStyle = .crossDissolve

        present(viewController, animated: true)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(spatialDataStateChanged(_:)),
                                               name: Notification.Name.spatialDataStateChanged,
                                               object: nil)
    }

    private func displayUnableToClearCacheWarning() {
        // Dismiss the loading screen
        dismiss(animated: true) { [weak self] in
            guard let `self` = self else {
                return
            }
            
            let alert = UIAlertController(title: GDLocalizedString("settings.clear_cache.no_service.title"),
                                          message: GDLocalizedString("settings.clear_cache.no_service.message"),
                                          preferredStyle: UIAlertController.Style.alert)
            
            alert.addAction(UIAlertAction(title: GDLocalizedString("general.alert.dismiss"), style: .cancel, handler: { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                
                NotificationCenter.default.removeObserver(self, name: Notification.Name.spatialDataStateChanged, object: nil)
                
                if self.reenableCalloutsAfterReload {
                    SettingsContext.shared.automaticCalloutsEnabled = true
                }
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func spatialDataStateChanged(_ notification: Notification) {
        guard let state = notification.userInfo?[SpatialDataContext.Keys.state] as? SpatialDataState else {
            return
        }
        
        guard state == .ready || state == .error else {
            return
        }
        
        NotificationCenter.default.removeObserver(self)
        
        if reenableCalloutsAfterReload {
            SettingsContext.shared.automaticCalloutsEnabled = true
        }
        
        dismiss(animated: true, completion: nil)
    }
}


private final class TroubleshootingModel: ObservableObject {
    @Published var server = SettingsContext.shared.servicesHostName
    @Published var disableKalman = !SettingsContext.shared.kalmanFilterEnabled {
        didSet { SettingsContext.shared.kalmanFilterEnabled = !disableKalman }
    }
}

private struct TroubleshootingScreen: View {
    @ObservedObject var model: TroubleshootingModel
    let checkAudio: () -> Void
    let configureServer: () -> Void
    let clearCache: () -> Void
    let deleteUserData: () -> Void
    @State private var accuracy: Double?

    var body: some View {
        Form {
            Section {
                if let accuracy {
                    Text(accuracyLabel(accuracy))
                }
            } header: {
                GDLocalizedTextView("troubleshooting.gps_status")
            } footer: {
                GDLocalizedTextView(SettingsContext.shared.metricUnits
                                    ? "troubleshooting.gps_status.explanation.meters"
                                    : "troubleshooting.gps_status.explanation.feet")
            }

            Section {
                Button(action: checkAudio) { GDLocalizedTextView("troubleshooting.check_audio") }
                    .accessibilityHint(GDLocalizedTextView("troubleshooting.check_audio.hint"))
            } header: {
                GDLocalizedTextView("troubleshooting.check_audio")
            } footer: {
                GDLocalizedTextView("troubleshooting.check_audio.explanation")
            }

            Section {
                Button(model.server, action: configureServer)
                    .accessibilityLabel(GDLocalizedTextView("troubleshooting.tile_server_url"))
            } header: {
                GDLocalizedTextView("troubleshooting.tile_server_url")
            } footer: {
                GDLocalizedTextView("troubleshooting.tile_server_url.explanation")
            }

            Section {
                Button(role: .destructive, action: clearCache) { GDLocalizedTextView("settings.clear_data") }
                    .accessibilityHint(GDLocalizedTextView("troubleshooting.cache.hint"))
            } header: {
                GDLocalizedTextView("troubleshooting.cache")
            } footer: {
                GDLocalizedTextView("troubleshooting.cache.explanation")
            }

            Section {
                Button(role: .destructive, action: deleteUserData) { GDLocalizedTextView("troubleshooting.user_data.button") }
            } header: {
                GDLocalizedTextView("troubleshooting.user_data")
            } footer: {
                GDLocalizedTextView("troubleshooting.user_data.explanation")
            }

            Section(GDLocalizationUnnecessary("Advanced")) {
                Toggle(GDLocalizationUnnecessary("Disable Kalman filter"), isOn: $model.disableKalman)
            }
        }
        .onAppear(perform: updateAccuracy)
        .onReceive(NotificationCenter.default.publisher(for: .locationUpdated).receive(on: RunLoop.main)) { _ in
            updateAccuracy()
        }
    }

    private func updateAccuracy() {
        accuracy = AppContext.shared.geolocationManager.location?.horizontalAccuracy
    }

    private func accuracyLabel(_ accuracy: Double) -> String {
        if SettingsContext.shared.metricUnits {
            return GDLocalizedString("troubleshooting.gps_status.meters", String(Int(accuracy)))
        }
        let feet = Measurement(value: accuracy, unit: UnitLength.meters).converted(to: .feet).value
        return GDLocalizedString("troubleshooting.gps_status.feet", String(Int(feet)))
    }
}
