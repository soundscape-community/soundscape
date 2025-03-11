//
//  AppContext.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import Combine
import CoreLocation
import CoreBluetooth

/// Enumeration describing the running state of the app.
///
/// - normal: The app is running as normal.
/// - sleep:  The `GeolocationManager` and `SpatialDataContext` have been shut off meaning
///           that the app is no longer using geolocation data or motion data and callouts
///           are no longer occurring.
/// - snooze: The app is in a low energy state similar to sleep mode but will automatically
///           wake up if the user moves a significant distance.
enum OperationState: String {
    case normal, sleep, snooze
}

extension Notification.Name {
    static let appOperationStateDidChange = Notification.Name("GDAAppOperationStateDidChange")
}

class AppContext {

    // MARK: Keys

    struct Keys {
        static let operationState = "GDAOperationStateKey"
    }
    
    // MARK: Static properties
    
    static let shared = AppContext()
    
    static let appDisplayName = "Soundscape"
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    static let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    static let appStoreId = "6449701760"

    static var appState: UIApplication.State = .inactive
    static let appLaunchedInBackground: Bool = UIApplication.shared.applicationState == .background
    
    // MARK: Properties
    
    private(set) var eventProcessor: EventProcessor
    private(set) var geolocationManager: GeolocationManager
    private(set) var spatialDataContext: SpatialDataContext
    private(set) var reverseGeocoder: ReverseGeocoderContext
    
    private(set) var offlineContext: OfflineContext
    private(set) var audioEngine: AudioEngineProtocol
    
    private var bleOnCancellable: AnyCancellable?
    private var bleAuthCancellable: AnyCancellable?
    private(set) lazy var bleManager: BLEManager = {
        // We use a lazy property as initializing the `BLEManager` for
        // the first time presents an iOS alert to approve BLE useage.
        return BLEManager()
    }()
    
    private(set) var experimentManager = ExperimentManager()
    private(set) var calloutHistory = CalloutHistory(maxItems: 40)
    private(set) var motionActivityContext = MotionActivityContext()
    private(set) var device = UIDeviceManager()
    
    let newFeatures = NewFeatures()

    private(set) var callManager = CallManager()
    private(set) var remoteCommandManager = RemoteCommandManager()

    private(set) var deviceManager: DeviceManager
    private(set) var cloudKeyValueStore: CloudKeyValueStore

    private(set) var isFirstLaunch = false
    
    var state = OperationState.normal {
        didSet {
            guard oldValue != state else {
                return
            }
            
            GDATelemetry.track("wake_state.\(state.rawValue)")

            if state != .normal {
                AudioSessionManager.removeNowPlayingInfo()
            }
            
            NotificationCenter.default.post(name: Notification.Name.appOperationStateDidChange, object: self, userInfo: [AppContext.Keys.operationState: state])
        }
    }

    var isInTutorialMode = false

    private var hasAttemptedToStart = false
    
    private var hasStarted = false
    
    /// Returns `true` if the app is currently in Street Preview, `false` otherwise.
    var isStreetPreviewing: Bool {
        return eventProcessor.isActive(behavior: StreetPreviewBehavior.self)
    }
    
    /// Returns `true` if route guidance is currently active, `false` otherwise.
    var isRouteGuidanceActive: Bool {
        return eventProcessor.isActive(behavior: RouteGuidance.self)
    }
    
    // MARK: Computed Properties

    class var isActive: Bool {
        return !(appLaunchedInBackground && appState == .background)
    }
    
    /// Returns the root view controller for the current app window
    class var rootViewController: UIViewController? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return nil }
        return appDelegate.window?.rootViewController
    }
    
    static var memoryAllocated: UInt64? {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            print("Error with task_info(): " + (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        return taskInfo.resident_size
    }
    
    static var secondaryRoadsContext: SecondaryRoadsContext {
        if shared.isStreetPreviewing {
            return SettingsContext.shared.previewIntersectionsIncludeUnnamedRoads ? .standard : .strict
        }
        
        if shared.motionActivityContext.isInVehicle {
            return .automotive
        }
        
        return .standard
    }
    
    // MARK: Initialization

    init() {
        audioEngine = AudioEngine(envSettings: DebugSettingsContext.shared, mixWithOthers: SettingsContext.shared.audioSessionMixesWithOthers)
        
        geolocationManager = GeolocationManager(isInMotion: motionActivityContext.isInMotion)
        
        deviceManager = DeviceManager(geolocationManager: geolocationManager)
        
        let destinationCollection = geolocationManager.heading(orderedBy: [.user, .device, .course])
        
        let destinationManager = DestinationManager(userLocation: geolocationManager.location,
                                                    audioEngine: audioEngine,
                                                    collectionHeading: destinationCollection)
        
        spatialDataContext = SpatialDataContext(geolocation: geolocationManager,
                                                motionActivity: motionActivityContext,
                                                services: OSMServiceModel(),
                                                device: device,
                                                destinationManager: destinationManager,
                                                settings: SettingsContext.shared)
        
        reverseGeocoder = ReverseGeocoderContext(spatialDataContext: spatialDataContext)
        
        let defaultBehavior = SoundscapeBehavior(geo: geolocationManager,
                                                 data: spatialDataContext,
                                                 reverseGeocoder: reverseGeocoder,
                                                 deviceManager: deviceManager,
                                                 motionActivity: motionActivityContext,
                                                 deviceMotion: DeviceMotionManager.shared)
        
        let stateMachine = CalloutStateMachine(audioEngine: audioEngine,
                                               geo: geolocationManager,
                                               motionActivityContext: motionActivityContext,
                                               history: calloutHistory)
        
        eventProcessor = EventProcessor(activeBehavior: defaultBehavior,
                                        stateMachine: stateMachine,
                                        audioEngine: audioEngine,
                                        data: spatialDataContext)
        
        offlineContext = OfflineContext(isNetworkConnectionAvailable: device.isNetworkConnectionAvailable,
                                        dataState: spatialDataContext.state)
        
        remoteCommandManager.toggleCommands(true)

        LocalizationContext.configureAccessibilityLanguage()
        
        cloudKeyValueStore = CloudKeyValueStore()
    }
    
    // MARK: Actions

    /// Clears the map data cache
    /// fixme: probably not the best place for this, but it is needed for updates 
    /// from version 1.1.2
    func clearMapDataCache() {
        // copied from StatusViewController.swift
        AppContext.shared.eventProcessor.hush(playSound: false)
        guard let database = try? RealmHelper.getDatabaseRealm() else {
            GDLogSpatialDataError("Error attempting to get database data!")
            return
        }
        
        var storedAddresses: [Address] = []
        for por in database.objects(ReferenceEntity.self) {
            if let entity = por.getPOI() as? Address, storedAddresses.contains(where: { $0.key == entity.key }) == false {
                // Copy the address
                storedAddresses.append(Address(value: entity))
            }
        }
        
        let success = AppContext.shared.spatialDataContext.clearCache()
        
        GDATelemetry.track("settings.clear_cache", with: ["keep_user_data": String(true)])
        
        guard success else {
            GDLogSpatialDataError("Error attempting to delete cached data!")
            return
        }
        
        guard storedAddresses.count > 0 else {
            GDLogSpatialDataWarn("Cached data deleted")
            return
        }
        
        // Save stored addresses
        guard let cache = try? RealmHelper.getCacheRealm() else {
            GDLogSpatialDataError("Cached data deleted, but couldn't get cache realm to restore addresses!")
            return
        }
        
        do {
            try cache.write {
                for address in storedAddresses {
                    cache.create(Address.self, value: address, update: .modified)
                }
            }
        } catch {
            GDLogSpatialDataError("Cached data deleted, but couldn't restore addresses!")
            return
        }
        
        GDLogSpatialDataWarn("Cached data deleted and addresses restored")
    }
    
    /// Starts the core components of the app including the sound context, the geolocation context,
    /// and the spatial data context. If the app is launched into the background by the system (e.g.
    /// download task completion, push notifications, etc.), callouts
    /// will not be turned on. Callouts are only turned on if the user opens the app themselves.
    func start(fromFirstLaunch: Bool = false) {
        hasAttemptedToStart = true
        isFirstLaunch = fromFirstLaunch
        
        guard AppContext.appState != .inactive else {
            return
        }
        
        startBLE()
        
        // If the user killed the app during the headset test, remove the temporary beacon
        if spatialDataContext.destinationManager.destination?.nickname == "HeadsetTest" {
            do {
                try spatialDataContext.destinationManager.clearDestination()
            } catch {
                GDLogAppError("Tried to clear test beacon but couldn't...")
            }
        }
        
        if AppContext.isActive {
            audioEngine.start()
            eventProcessor.start()
        }
        
        geolocationManager.start()
        
        DeviceMotionManager.shared.startDeviceMotionUpdates()
        cloudKeyValueStore.start()
        spatialDataContext.start()
        
        // if the app was updated or there is no lastRunVersion, clear the cache
        let lastRunVersion = UserDefaults.standard.string(forKey: "lastRunVersion") ?? ""
        if lastRunVersion != AppContext.appVersion {
            clearMapDataCache()
            UserDefaults.standard.set(AppContext.appVersion, forKey: "lastRunVersion")
        }
        
        // Do not play the app launch sound if onboarding is in-progress
        if !(eventProcessor.activeBehavior is OnboardingBehavior) {
            eventProcessor.process(GlyphEvent(.appLaunch))
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.pushNotificationManager.start()
        
        hasStarted = true
    }
    
    private func startBLE() {
        guard deviceManager.hasStoredDevices else {
            // Only initialize Bluetooth if we have stored devices.
            // If we don't, it will be initialized when accessed.
            return
        }
        
        // Wait for the central BLE manager to enter the powered ON state before trying to connect to any devices
        bleOnCancellable = NotificationCenter.default
            .publisher(for: .bluetoothDidUpdateState)
            .filter({ notification in
                guard let state = notification.userInfo?[BLEManager.NotificationKeys.state] as? CBManagerState else { return false }
                return state == .poweredOn
            })
            .sink { _ in
                self.bleOnCancellable = nil
                self.deviceManager.loadAndConnectDevices()
            }
        
        // Show error alert if BLE is unauthorized
        bleAuthCancellable = NotificationCenter.default
            .publisher(for: .bluetoothDidUpdateState)
            .filter({ notification in
                guard let state = notification.userInfo?[BLEManager.NotificationKeys.state] as? CBManagerState else { return false }
                return state == .unauthorized
            })
            .receive(on: RunLoop.main)
            .sink { _ in
                guard let rootViewController = AppContext.rootViewController else { return }
                let alert = ErrorAlerts.buildBLEAlert()
                rootViewController.present(alert, animated: true)
            }
        
        // Initialized the lazy property
        _ = bleManager
    }
    
    /// Stops location updates and motion activity updates
    func goToSleep() {
        // Put the active behavior to sleep and hush the app (clears the callout queue)
        eventProcessor.sleep()
        
        geolocationManager.stop()
        DeviceMotionManager.shared.stopDeviceMotionUpdates()
        spatialDataContext.stop()
        
        state = .sleep
    }
    
    /// Stops the Spatial Data Context, but does not stop Geolocation Context like sleeping
    /// does. Instead, the geolocation context is put in a low energy state where it only receives
    /// significant location updates. If the user moves a significant distance, openscape will wake
    /// up automatically.
    func snooze() {
        // The snooze call can trigger a new location update (because the location manager is stopped,
        // reconfigured, and restarted), so the call to snooze should come after the Spatial Data
        // Context has already been stopped.
        spatialDataContext.stop()

        geolocationManager.snoozeDelegate = self
        geolocationManager.snooze()
        
        DeviceMotionManager.shared.stopDeviceMotionUpdates()
        
        state = .snooze
    }
    
    /// Resumes location updates and motion activity updates
    func wakeUp() {
        guard state == .sleep || state == .snooze else {
            return
        }
        
        geolocationManager.start()
        DeviceMotionManager.shared.startDeviceMotionUpdates()
        spatialDataContext.start()
        
        state = .normal
        
        // Resume the paused behavior if needed
        eventProcessor.wake()
    }
    
    func validateActive() {
        guard !hasStarted, hasAttemptedToStart else {
            if !hasStarted {
                GDLogAppVerbose("AppContext has not yet started...")
            } else {
                GDLogAppVerbose("Validated: AppContext has been started")
            }
            return
        }
        
        GDLogAppVerbose("AppContext failed to start previously. Calling start() again...")
        
        // Call start again passing the same value that was previously passed for isFirstLaunch
        start(fromFirstLaunch: isFirstLaunch)
    }
    
    static func process(_ event: Event) {
        shared.eventProcessor.process(event)
    }
}

extension AppContext: GeolocationManagerSnoozeDelegate {
    
    func snoozeDidFail() {
        // Failed to snooze `GeolocationManager`
        // Wake up the app
        wakeUp()
    }
    
    func snoozeDidTrigger() {
        // Leave snoozed state
        wakeUp()
    }
    
}

extension AppContext {
    
    // TODO: Update the following links with your URLs
    
    struct Links {
        static func privacyPolicyURL(for locale: Locale) -> URL {
            return URL(string: "https://ialabs.ie/privacy-policy")!
        }
        
        static func servicesAgreementURL(for locale: Locale) -> URL {
            return URL(string: "https://soundscape.services")!
        }
    
        static func youtubeURL(for locale: Locale) -> URL {
            return URL(string: "https://www.youtube.com/@SoundscapeCommunity")!
        }

        static let companySupportURL = URL(string: "https://discord.gg/XakpNsVMBZ")!
        
        static let accessibilityFrance = URL(string: "https://soundscape.services")!
    }
    
}
