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
import SSGeo

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

@MainActor
protocol RouteRuntimeProviding {
    func routeCurrentUserLocation() -> CLLocation?
    func routeActiveRouteDatabaseID() -> String?
    func routeDeactivateActiveBehavior()
    func routeStoreInCloud(_ route: Route)
    func routeUpdateInCloud(_ route: Route)
    func routeRemoveFromCloud(_ route: Route)
    func routeCurrentMotionActivityRawValue() -> String
}

@MainActor
protocol ReferenceEntityRuntimeProviding {
    func referenceCurrentUserLocation() -> CLLocation?
    func referenceStoreInCloud(_ entity: ReferenceEntity)
    func referenceUpdateInCloud(_ entity: ReferenceEntity)
    func referenceRemoveFromCloud(_ entity: ReferenceEntity)
    func referenceSetDestinationTemporaryIfMatchingID(_ id: String) throws -> Bool
    func referenceClearDestinationForCacheReset() throws
    func referenceRemoveCalloutHistoryForMarkerID(_ markerID: String)
}

@MainActor
protocol SpatialDataEntityRuntimeProviding {
    func spatialDataEntityCurrentUserLocation() -> CLLocation?
}

@MainActor
protocol DestinationManagerRuntimeProviding {
    func destinationManagerCurrentUserLocation() -> CLLocation?
    func destinationManagerIsRouteGuidanceActive() -> Bool
    func destinationManagerIsRouteOrTourGuidanceActive() -> Bool
    func destinationManagerIsBeaconCalloutGeneratorBlocked() -> Bool
}

@MainActor
protocol SpatialDataContextRuntimeProviding {
    func spatialDataContextCurrentUserLocation() -> CLLocation?
    func spatialDataContextPerformInitialCloudSync(_ completion: @escaping () -> Void)
    func spatialDataContextClearCalloutHistory()
    func spatialDataContextIsApplicationInNormalState() -> Bool
    func spatialDataContextUpdateAudioEngineUserLocation(_ location: CLLocation)
}

@MainActor
protocol DataRuntimeProviders: RouteRuntimeProviding,
                               ReferenceEntityRuntimeProviding,
                               SpatialDataEntityRuntimeProviding,
                               DestinationManagerRuntimeProviding,
                               SpatialDataContextRuntimeProviding {}

@MainActor
enum DataRuntimeProviderRegistry {
    private static let unconfiguredProviders = UnconfiguredDataRuntimeProviders()
    private(set) static var providers: DataRuntimeProviders = unconfiguredProviders

    static func configure(with providers: DataRuntimeProviders) {
        self.providers = providers
    }

    static func resetForTesting() {
        providers = unconfiguredProviders
    }
}

@MainActor
private final class UnconfiguredDataRuntimeProviders: DataRuntimeProviders {
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func debugAssertUnconfigured(_ method: StaticString) {
#if DEBUG
        if !Self.isRunningUnitTests {
            assertionFailure("DataRuntimeProviderRegistry is unconfigured when calling \(method)")
        }
#endif
    }

    func routeCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func routeActiveRouteDatabaseID() -> String? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func routeDeactivateActiveBehavior() {
        debugAssertUnconfigured(#function)
    }

    func routeStoreInCloud(_ route: Route) {
        debugAssertUnconfigured(#function)
    }

    func routeUpdateInCloud(_ route: Route) {
        debugAssertUnconfigured(#function)
    }

    func routeRemoveFromCloud(_ route: Route) {
        debugAssertUnconfigured(#function)
    }

    func routeCurrentMotionActivityRawValue() -> String {
        debugAssertUnconfigured(#function)
        return "unknown"
    }

    func referenceCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func referenceStoreInCloud(_ entity: ReferenceEntity) {
        debugAssertUnconfigured(#function)
    }

    func referenceUpdateInCloud(_ entity: ReferenceEntity) {
        debugAssertUnconfigured(#function)
    }

    func referenceRemoveFromCloud(_ entity: ReferenceEntity) {
        debugAssertUnconfigured(#function)
    }

    func referenceSetDestinationTemporaryIfMatchingID(_ id: String) throws -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func referenceClearDestinationForCacheReset() throws {
        debugAssertUnconfigured(#function)
    }

    func referenceRemoveCalloutHistoryForMarkerID(_ markerID: String) {
        debugAssertUnconfigured(#function)
    }

    func spatialDataEntityCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func destinationManagerCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func destinationManagerIsRouteGuidanceActive() -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func destinationManagerIsRouteOrTourGuidanceActive() -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func destinationManagerIsBeaconCalloutGeneratorBlocked() -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func spatialDataContextCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func spatialDataContextPerformInitialCloudSync(_ completion: @escaping () -> Void) {
        debugAssertUnconfigured(#function)
        completion()
    }

    func spatialDataContextClearCalloutHistory() {
        debugAssertUnconfigured(#function)
    }

    func spatialDataContextIsApplicationInNormalState() -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func spatialDataContextUpdateAudioEngineUserLocation(_ location: CLLocation) {
        debugAssertUnconfigured(#function)
    }
}

@MainActor
final class AppContextDataRuntimeProviders: DataRuntimeProviders {
    private unowned let context: AppContext

    init(context: AppContext) {
        self.context = context
    }

    func routeCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func routeActiveRouteDatabaseID() -> String? {
        guard let routeGuidance = context.eventProcessor.activeBehavior as? RouteGuidance else {
            return nil
        }

        guard case let .database(activeID) = routeGuidance.content.source else {
            return nil
        }

        return activeID
    }

    func routeDeactivateActiveBehavior() {
        context.eventProcessor.deactivateCustom()
    }

    func routeStoreInCloud(_ route: Route) {
        context.cloudKeyValueStore.store(route: route)
    }

    func routeUpdateInCloud(_ route: Route) {
        context.cloudKeyValueStore.update(route: route)
    }

    func routeRemoveFromCloud(_ route: Route) {
        context.cloudKeyValueStore.remove(route: route)
    }

    func routeCurrentMotionActivityRawValue() -> String {
        context.motionActivityContext.currentActivity.rawValue
    }

    func referenceCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func referenceStoreInCloud(_ entity: ReferenceEntity) {
        context.cloudKeyValueStore.store(referenceEntity: entity)
    }

    func referenceUpdateInCloud(_ entity: ReferenceEntity) {
        context.cloudKeyValueStore.update(referenceEntity: entity)
    }

    func referenceRemoveFromCloud(_ entity: ReferenceEntity) {
        context.cloudKeyValueStore.remove(referenceEntity: entity)
    }

    func referenceSetDestinationTemporaryIfMatchingID(_ id: String) throws -> Bool {
        guard let destination = context.spatialDataContext.destinationManager.destination,
              destination.id == id else {
            return false
        }

        try destination.setTemporary(true)
        return true
    }

    func referenceClearDestinationForCacheReset() throws {
        try context.spatialDataContext.destinationManager.clearDestination(logContext: "settings.clear_cache")
    }

    func referenceRemoveCalloutHistoryForMarkerID(_ markerID: String) {
        context.calloutHistory.remove { callout in
            if let poiCallout = callout as? POICallout,
               let calloutMarker = poiCallout.marker {
                return calloutMarker.id == markerID
            }

            return false
        }
    }

    func spatialDataEntityCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func destinationManagerCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func destinationManagerIsRouteGuidanceActive() -> Bool {
        context.eventProcessor.activeBehavior is RouteGuidance
    }

    func destinationManagerIsRouteOrTourGuidanceActive() -> Bool {
        context.eventProcessor.activeBehavior is RouteGuidance ||
            context.eventProcessor.activeBehavior is GuidedTour
    }

    func destinationManagerIsBeaconCalloutGeneratorBlocked() -> Bool {
        context.eventProcessor.activeBehavior.blockedAutoGenerators.contains(where: { $0 == BeaconCalloutGenerator.self })
    }

    func spatialDataContextCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func spatialDataContextPerformInitialCloudSync(_ completion: @escaping () -> Void) {
        context.cloudKeyValueStore.syncReferenceEntities(reason: .initialSync) {
            self.context.cloudKeyValueStore.syncRoutes(reason: .initialSync)
            completion()
        }
    }

    func spatialDataContextClearCalloutHistory() {
        context.calloutHistory.clear()
    }

    func spatialDataContextIsApplicationInNormalState() -> Bool {
        context.state == .normal
    }

    func spatialDataContextUpdateAudioEngineUserLocation(_ location: CLLocation) {
        context.audioEngine.updateUserLocation(location)
    }
}

@MainActor
protocol UserLocationStoreRuntimeProviding {
    func userLocationStoreInitialUserLocation() -> SSGeoLocation?
}

@MainActor
protocol BeaconDetailRuntimeProviding {
    func beaconDetailIsUserWithinDestinationGeofence(_ userLocation: SSGeoLocation) -> Bool
}

@MainActor
protocol BeaconStoreRuntimeProviding {
    func beaconStoreDestinationManager() -> DestinationManagerProtocol?
    func beaconStoreActiveRouteGuidance() -> RouteGuidance?
}

@MainActor
protocol RouteGuidanceStateStoreRuntimeProviding {
    func routeGuidanceStateStoreActiveRouteGuidance() -> RouteGuidance?
}

@MainActor
protocol GuidedTourStateStoreRuntimeProviding {
    func guidedTourStateStoreActiveTour() -> GuidedTour?
}

@MainActor
protocol AudioFileStoreRuntimeProviding {
    func audioFileStorePlay(_ url: URL) -> AudioPlayerIdentifier?
    func audioFileStoreStop(_ id: AudioPlayerIdentifier)
}

@MainActor
protocol VisualRuntimeProviders: UserLocationStoreRuntimeProviding,
                                 BeaconDetailRuntimeProviding,
                                 BeaconStoreRuntimeProviding,
                                 RouteGuidanceStateStoreRuntimeProviding,
                                 GuidedTourStateStoreRuntimeProviding,
                                 AudioFileStoreRuntimeProviding {}

@MainActor
enum VisualRuntimeProviderRegistry {
    private static let unconfiguredProviders = UnconfiguredVisualRuntimeProviders()
    private(set) static var providers: VisualRuntimeProviders = unconfiguredProviders

    static func configure(with providers: VisualRuntimeProviders) {
        self.providers = providers
    }

    static func resetForTesting() {
        providers = unconfiguredProviders
    }
}

@MainActor
private final class UnconfiguredVisualRuntimeProviders: VisualRuntimeProviders {
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func debugAssertUnconfigured(_ method: StaticString) {
#if DEBUG
        if !Self.isRunningUnitTests {
            assertionFailure("VisualRuntimeProviderRegistry is unconfigured when calling \(method)")
        }
#endif
    }

    func userLocationStoreInitialUserLocation() -> SSGeoLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func beaconDetailIsUserWithinDestinationGeofence(_ userLocation: SSGeoLocation) -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func beaconStoreDestinationManager() -> DestinationManagerProtocol? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func beaconStoreActiveRouteGuidance() -> RouteGuidance? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func routeGuidanceStateStoreActiveRouteGuidance() -> RouteGuidance? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func guidedTourStateStoreActiveTour() -> GuidedTour? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func audioFileStorePlay(_ url: URL) -> AudioPlayerIdentifier? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func audioFileStoreStop(_ id: AudioPlayerIdentifier) {
        debugAssertUnconfigured(#function)
    }
}

@MainActor
final class AppContextVisualRuntimeProviders: VisualRuntimeProviders {
    private unowned let context: AppContext

    init(context: AppContext) {
        self.context = context
    }

    func userLocationStoreInitialUserLocation() -> SSGeoLocation? {
        context.geolocationManager.location?.ssGeoLocation
    }

    func beaconDetailIsUserWithinDestinationGeofence(_ userLocation: SSGeoLocation) -> Bool {
        context.spatialDataContext.destinationManager.isUserWithinGeofence(userLocation)
    }

    func beaconStoreDestinationManager() -> DestinationManagerProtocol? {
        context.spatialDataContext.destinationManager
    }

    func beaconStoreActiveRouteGuidance() -> RouteGuidance? {
        context.eventProcessor.activeBehavior as? RouteGuidance
    }

    func routeGuidanceStateStoreActiveRouteGuidance() -> RouteGuidance? {
        context.eventProcessor.activeBehavior as? RouteGuidance
    }

    func guidedTourStateStoreActiveTour() -> GuidedTour? {
        context.eventProcessor.activeBehavior as? GuidedTour
    }

    func audioFileStorePlay(_ url: URL) -> AudioPlayerIdentifier? {
        context.audioEngine.play(GenericSound(url))
    }

    func audioFileStoreStop(_ id: AudioPlayerIdentifier) {
        context.audioEngine.stop(id)
    }
}

@MainActor
protocol RouteGuidanceRuntimeProviding {
    func routeGuidanceCurrentUserLocation() -> CLLocation?
    func routeGuidanceSecondaryRoadsContext() -> SecondaryRoadsContext
}

@MainActor
protocol GuidedTourRuntimeProviding {
    func guidedTourCurrentUserLocation() -> CLLocation?
    func guidedTourSecondaryRoadsContext() -> SecondaryRoadsContext
    func guidedTourRemoveRegisteredPOIs()
}

@MainActor
protocol OnboardingRuntimeProviding {
    func onboardingDestinationManager() -> DestinationManagerProtocol?
    func onboardingCurrentUserLocation() -> CLLocation?
    func onboardingCurrentPresentationHeading() -> CLLocationDirection?
    func onboardingIsGeolocationAuthorized() -> Bool
    func onboardingIsMotionActivityAuthorized() -> Bool
}

@MainActor
protocol BehaviorRuntimeProviders: RouteGuidanceRuntimeProviding, GuidedTourRuntimeProviding, OnboardingRuntimeProviding {
    func behaviorAudioOutputType() -> String
}

@MainActor
enum BehaviorRuntimeProviderRegistry {
    private static let unconfiguredProviders = UnconfiguredBehaviorRuntimeProviders()
    private(set) static var providers: BehaviorRuntimeProviders = unconfiguredProviders

    static func configure(with providers: BehaviorRuntimeProviders) {
        self.providers = providers
    }

    static func resetForTesting() {
        providers = unconfiguredProviders
    }
}

@MainActor
private final class UnconfiguredBehaviorRuntimeProviders: BehaviorRuntimeProviders {
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func debugAssertUnconfigured(_ method: StaticString) {
#if DEBUG
        if !Self.isRunningUnitTests {
            assertionFailure("BehaviorRuntimeProviderRegistry is unconfigured when calling \(method)")
        }
#endif
    }

    func routeGuidanceCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func routeGuidanceSecondaryRoadsContext() -> SecondaryRoadsContext {
        debugAssertUnconfigured(#function)
        return .standard
    }

    func guidedTourCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func guidedTourSecondaryRoadsContext() -> SecondaryRoadsContext {
        debugAssertUnconfigured(#function)
        return .standard
    }

    func guidedTourRemoveRegisteredPOIs() {
        debugAssertUnconfigured(#function)
    }

    func onboardingDestinationManager() -> DestinationManagerProtocol? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func onboardingCurrentUserLocation() -> CLLocation? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func onboardingCurrentPresentationHeading() -> CLLocationDirection? {
        debugAssertUnconfigured(#function)
        return nil
    }

    func onboardingIsGeolocationAuthorized() -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func onboardingIsMotionActivityAuthorized() -> Bool {
        debugAssertUnconfigured(#function)
        return false
    }

    func behaviorAudioOutputType() -> String {
        debugAssertUnconfigured(#function)
        return "unknown"
    }
}

@MainActor
final class AppContextBehaviorRuntimeProviders: BehaviorRuntimeProviders {
    private unowned let context: AppContext

    init(context: AppContext) {
        self.context = context
    }

    func routeGuidanceCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func routeGuidanceSecondaryRoadsContext() -> SecondaryRoadsContext {
        AppContext.secondaryRoadsContext
    }

    func guidedTourCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func guidedTourSecondaryRoadsContext() -> SecondaryRoadsContext {
        AppContext.secondaryRoadsContext
    }

    func guidedTourRemoveRegisteredPOIs() {
        context.eventProcessor.process(RemoveRegisteredPOIs())
    }

    func onboardingDestinationManager() -> DestinationManagerProtocol? {
        context.spatialDataContext.destinationManager
    }

    func onboardingCurrentUserLocation() -> CLLocation? {
        context.geolocationManager.location
    }

    func onboardingCurrentPresentationHeading() -> CLLocationDirection? {
        context.geolocationManager.presentationHeading.value
    }

    func onboardingIsGeolocationAuthorized() -> Bool {
        context.geolocationManager.isAuthorized
    }

    func onboardingIsMotionActivityAuthorized() -> Bool {
        context.motionActivityContext.isAuthorized
    }

    func behaviorAudioOutputType() -> String {
        context.audioEngine.outputType
    }
}

@MainActor
class AppContext {

    // MARK: Keys

    struct Keys {
        static let operationState = "GDAOperationStateKey"
    }
    
    // MARK: Static properties
    
    static let shared = AppContext()
    
    nonisolated(unsafe) static let appDisplayName = "Soundscape"
    nonisolated(unsafe) static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    nonisolated(unsafe) static let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    nonisolated(unsafe) static let appStoreId = "6449701760"

    static var appState: UIApplication.State = .inactive
    nonisolated(unsafe) static let appLaunchedInBackground: Bool = UIApplication.shared.applicationState == .background
    
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
                                                 deviceMotion: DeviceMotionManager.shared,
                                                 audioEngine: audioEngine)
        
        let calloutCoordinator = CalloutCoordinator(audioEngine: audioEngine,
                                geo: geolocationManager,
                                motionActivityContext: motionActivityContext,
                                history: calloutHistory)

        eventProcessor = EventProcessor(activeBehavior: defaultBehavior,
                        calloutCoordinator: calloutCoordinator,
                        audioEngine: audioEngine,
                        data: spatialDataContext)
        
        offlineContext = OfflineContext(isNetworkConnectionAvailable: device.isNetworkConnectionAvailable,
                                        dataState: spatialDataContext.state)
        
        remoteCommandManager.toggleCommands(true)

        LocalizationContext.configureAccessibilityLanguage()
        
        cloudKeyValueStore = CloudKeyValueStore()

        DataRuntimeProviderRegistry.configure(with: AppContextDataRuntimeProviders(context: self))
        VisualRuntimeProviderRegistry.configure(with: AppContextVisualRuntimeProviders(context: self))
        BehaviorRuntimeProviderRegistry.configure(with: AppContextBehaviorRuntimeProviders(context: self))
    }
    
    // MARK: Actions
    
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
