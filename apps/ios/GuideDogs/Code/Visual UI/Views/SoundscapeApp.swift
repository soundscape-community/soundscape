// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Combine
import SwiftUI
import UIKit

@main
struct SoundscapeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var launch = AppLaunchModel()
    @StateObject private var navigation = AppNavigationModel.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch navigation.coordinator.stage {
                case .starting:
                    launchView
                case .onboarding:
                    if let onboarding = launch.onboarding {
                        OnboardingWelcomeView(context: .firstUse)
                            .environmentObject(onboarding)
                    }
                case .telemetryConsent:
                    TelemetryConsentView(onChoice: launch.startHome)
                case .home:
                    RouteStack(path: navigation.path) {
                        HomeNavigationBridge()
                            .id(launch.homeGeneration)
                            .ignoresSafeArea()
                            .toolbar(.hidden, for: .navigationBar)
                    } destination: { route in
                        AppDestinationView(route: route, navigation: navigation)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .sheet(isPresented: navigation.helpTutorial) {
                        HelpOnboardingSheet()
                    }
                    .fullScreenCover(isPresented: navigation.newFeatures) {
                        NewFeaturesPresentation(service: AppContext.shared.newFeatures)
                    }
                }
            }
            .background(WindowConfigurationView())
            .onAppear(perform: launch.start)
            .onReceive(NotificationCenter.default.publisher(for: .rebuildHome)) { _ in
                navigation.update { $0.rebuildHome() }
                launch.homeGeneration += 1
            }
        }
    }

    private var launchView: some View {
        ZStack(alignment: .bottom) {
            Color("launchBackground").ignoresSafeArea()

            VStack(spacing: 12) {
                Image("launchScreenLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .accessibilityHidden(true)
                Text(verbatim: "Soundscape")
                    .font(.largeTitle.weight(.thin))
            }
            .frame(maxHeight: .infinity)

            ProgressView()
                .controlSize(.large)
                .tint(.white)
                .padding(.bottom, 35)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .accessibilityIgnoresInvertColors()
    }
}

private final class AppLaunchModel: ObservableObject, ExperimentManagerDelegate {
    private let navigation = AppNavigationModel.shared
    @Published var homeGeneration = 0
    private(set) var onboarding: OnboardingViewModel?
    private var didStart = false
    private var validator: TTSVoiceValidator?
    private var validation: AnyCancellable?

    func start() {
        guard !didStart else { return }
        didStart = true

        LoggingContext.shared.start()
        GDLogAppInfo("Device info: \(UIDevice.current.modelName), iOS \(UIDevice.current.systemVersion), v\(AppContext.appVersion) (\(AppContext.appBuild)), \(LocalizationContext.currentAppLocale.identifierHyphened)")

        if BuildSettings.isTesting {
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
        } else {
            SpatialDataCache.useDefaultSearchProviders()
            SpatialDataCache.useDefaultGeocoder()
        }

        SettingsContext.shared.automaticCalloutsEnabled = true
        GDATelemetry.helper = TelemetryHelper(appContext: AppContext.shared)

        guard let id = SettingsContext.shared.voiceId else {
            finishInitialization()
            return
        }

        let validator = TTSVoiceValidator(identifier: id)
        self.validator = validator
        validation = validator.validate()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                if !isValid {
                    SettingsContext.shared.voiceId = nil
                    GDLogAudioVerbose("TTS voice no longer available (\(id)). Reverting to default.")
                }

                self?.validator = nil
                self?.validation = nil
                self?.finishInitialization()
            }
    }

    private func finishInitialization() {
        GDATelemetry.snapshotsReady()
        AppContext.shared.experimentManager.delegate = self
        AppContext.shared.experimentManager.initialize()
    }

    func onExperimentManagerReady() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.navigation.coordinator.stage == .starting else { return }
            AppContext.shared.experimentManager.delegate = nil

            if !FirstUseExperience.didComplete(.oobe) {
                SettingsContext.shared.newFeaturesLastDisplayedVersion = AppContext.appVersion
                self.onboarding = OnboardingViewModel { [weak self] in
                    // The onboarding headset flow has already started the app services.
                    self?.navigation.update { $0.finishOnboarding() }
                }
                self.navigation.update { $0.finishLaunch(needsOnboarding: true, needsConsent: false) }
            } else if SettingsContext.shared.telemetryConsentChoiceMade {
                AppContext.shared.start()
                self.navigation.update { $0.finishLaunch(needsOnboarding: false, needsConsent: false) }
            } else {
                self.navigation.update { $0.finishLaunch(needsOnboarding: false, needsConsent: true) }
            }
        }
    }

    func startHome() {
        AppContext.shared.start()
        navigation.update { $0.finishConsent() }
    }
}

private struct HomeNavigationBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> NavigationController {
        let home = HomeViewController()
        let controller = NavigationController(rootViewController: home)
        LaunchHelper.homePresenter = home
        controller.navigationBar.barStyle = .black
        controller.view.accessibilityIgnoresInvertColors = true
        LaunchHelper.homeNavigationController = controller
        return controller
    }

    func updateUIViewController(_ controller: NavigationController, context: Context) {}

    static func dismantleUIViewController(_ controller: NavigationController, coordinator: ()) {
        if LaunchHelper.homeNavigationController === controller {
            LaunchHelper.homeNavigationController = nil
            LaunchHelper.homePresenter = nil
        }
    }
}

private struct WindowConfigurationView: UIViewRepresentable {
    func makeUIView(context: Context) -> WindowObserverView { WindowObserverView() }

    func updateUIView(_ view: WindowObserverView, context: Context) {}

    final class WindowObserverView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.configureForSoundscape()
        }
    }
}
