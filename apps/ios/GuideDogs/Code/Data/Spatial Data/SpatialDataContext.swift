//
//  SpatialDataContext.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SSData
import CoreLocation

enum SpatialDataState {
    case error
    case loadingCategories
    case waitingForLocation
    case loading
    case ready
}

enum SpatialDataContextError: Error {
    case noCategories
    case missingData
}

extension Notification.Name {
    static let spatialDataStateChanged = Notification.Name("GDASpatialDataStateChanged")
    static let tilesDidUpdate = Notification.Name("TilesDidUpdate")
    static let locationUpdated = Notification.Name("GDALocationUpdated")
}

// MARK: -

class SpatialDataContext: NSObject, SpatialDataProtocol {
    
    // MARK: Constants
    
    struct Keys {
        static let state = "GDAGeolocationState"
        static let location = "GDAGeolocation"
        static let categoriesVersion = "GDACategoriesVersion"
    }
    
    // MARK: - Properties
    
    static let zoomLevel: UInt = 16
    static let cacheDistance: CLLocationDistance = 1000
    static let initialPOISearchDistance: CLLocationDistance = 200
    static let expansionPOISearchDistance: CLLocationDistance = 200
    static let refreshTimeInterval: TimeInterval = 5.0
    static let refreshDistanceInterval: CLLocationDistance = 5.0

    private(set) weak var geolocationManager: GeolocationManagerProtocol?
    private(set) var motionActivityContext: MotionActivityProtocol

    private weak var deviceContext: UIDeviceManager!
    private let serviceModel: OSMServiceModelProtocol
    
    let destinationManager: DestinationManagerProtocol
    
    private weak var settings: SettingsContext?

    fileprivate var updateFilter: MotionActivityUpdateFilter
    fileprivate var superCategories: SuperCategories?
    
    fileprivate var currentLocation: CLLocation?
    fileprivate var originalRequestLocation: CLLocation?

    private var expectedTilesCount = 0
    private var canceledTilesCount = 0
    
    // MARK: Synchronized Properties
    
    private let networkQueue = DispatchQueue(label: "services.soundscape.spatialdata.network", qos: .utility)
    private var dispatchQueue = DispatchQueue(label: "services.soundscape.spatialdata", qos: .utility, attributes: .concurrent)
    private var fetchingTiles = false
    private var tileRequestID = UUID()
    private var trackedStore: SpatialTileStore?
    
    /// Set of tiles the spatial data context is currently using to generate the list of spatial data result entities around the user
    private var tiles: Set<VectorTile> = []
    
    // MARK: Error Recovery Properties
    
    private let errorRecoveryDelay = 60.0
    private var errorRecoveryTask: DispatchWorkItem?
    
    // MARK: Observed Properties
    
    private(set) var state = SpatialDataState.loadingCategories {
        didSet {
            guard oldValue != state else {
                return
            }
            
            if state == .error {
                scheduleErrorRecovery()
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.spatialDataStateChanged, object: self, userInfo: [SpatialDataContext.Keys.state: self.state])
            }
        }
    }
    
    // MARK: Computed Properties
    
    private var currentTile: VectorTile? {
        guard let location = currentLocation else {
            return nil
        }
        
        return VectorTile.tileForLocation(location, zoom: SpatialDataContext.zoomLevel)
    }
    
    var loadedSpatialData: Bool {
        var loadedSpatialData = false
        
        dispatchQueue.sync {
            loadedSpatialData = !fetchingTiles && superCategories != nil && tiles.count > 0
        }
        
        return loadedSpatialData
    }
    
    var currentTiles: [VectorTile] {
        var currentTiles: [VectorTile] = []
        
        dispatchQueue.sync {
            for tile in tiles {
                currentTiles.append(tile)
            }
        }
        
        return currentTiles
    }
    
    // MARK: - Initialization

    init(geolocation: GeolocationManagerProtocol,
         motionActivity: MotionActivityProtocol,
         services: OSMServiceModelProtocol,
         device: UIDeviceManager,
         destinationManager destinations: DestinationManagerProtocol,
         settings settingsContext: SettingsContext) {
        
        deviceContext = device
        geolocationManager = geolocation
        motionActivityContext = motionActivity

        serviceModel = services
        destinationManager = destinations
        settings = settingsContext
        
        updateFilter = MotionActivityUpdateFilter(minTime: SpatialDataContext.refreshTimeInterval,
                                                  minDistance: SpatialDataContext.refreshDistanceInterval,
                                                  motionActivity: motionActivity)

        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onNetworkConnectionDidChange), name: Notification.Name.networkConnectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSpatialStoreInvalidated),
                                               name: .spatialStoreInvalidated, object: nil)
        
        // Parse the super categories from the assets file
        guard let categories = SpatialDataContext.loadDefaultCategories() else {
            GDLogAppError("Unable to load super categories")
            state = .error
            superCategories = [:]
            return
        }
        
        state = .waitingForLocation
        superCategories = categories
        
        // Register to receive a notification when the app has finished initializing
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppDidInitialize), name: NSNotification.Name.appDidInitialize, object: nil)
        
    }
    
    @objc private func onAppDidInitialize() {
        // Run the initial spatial data update
        
        guard let location = AppContext.shared.geolocationManager.location else {
            GDLogSpatialDataWarn("SpatialDataContext initialized, but no location data is available yet...")
            return
        }
        
        currentLocation = location
        
        guard updateFilter.shouldUpdate(location: location) else {
            GDLogSpatialDataWarn("SpatialDataContext initialized, but should update returned false...")
            return
        }
        
        state = .loading
        
        // There is no point to try updating if we don't have a network connection
        guard deviceContext.isNetworkConnectionAvailable else {
            let tile = VectorTile.tileForLocation(location, zoom: SpatialDataContext.zoomLevel)
            
            // This is only an error if the current tile isn't cached
            if SpatialDataContext.isCached(tile: tile) {
                state = .ready
            } else {
                state = .error
            }
            
            return
        }
        
        updateSpatialDataAsync(location: location)
    }
    
    func start() {
        geolocationManager?.updateDelegate = self
        
        motionActivityContext.startActivityUpdates()
        
    }

    func stop() {
        geolocationManager?.updateDelegate = nil
        
        motionActivityContext.stopActivityUpdates()
    }
    
    // MARK: - Instance Methods
    
    func clearCache() -> Bool {
        do {
            try dispatchQueue.sync(flags: .barrier) {
                let store = try StorageContext.shared.withSpatialStore { store in
                    try store.reset()
                    return store
                }
                invalidateTrackedTiles()
                do {
                    try store.reclaimDiskSpace()
                } catch {
                    GDLogSpatialDataError("Unable to reclaim disk space after clearing the spatial cache: \(error)")
                }
            }
        } catch {
            GDLogSpatialDataError("Unable to clear the spatial cache: \(error)")
            return false
        }

        AppContext.shared.calloutHistory.clear()
        
        if let loc = geolocationManager?.location {
            updateSpatialDataAsync(location: loc, reloadPORs: true)
        }
        
        return true
    }
    
    private func invalidateTrackedTiles() {
        trackedStore = nil
        tileRequestID = UUID()
        fetchingTiles = false
        tiles.removeAll()
    }

    @objc private func onSpatialStoreInvalidated(_ notification: Notification) {
        guard notification.object as? StorageContext === StorageContext.shared else { return }
        let invalidated = dispatchQueue.sync(flags: .barrier) {
            guard let trackedStore, !StorageContext.shared.isCurrentSpatialStore(trackedStore) else { return false }
            invalidateTrackedTiles()
            return true
        }
        if invalidated, deviceContext.isNetworkConnectionAvailable, let location = currentLocation ?? originalRequestLocation {
            updateSpatialDataAsync(location: location, reloadPORs: true)
        }
    }

    func getDataView(for location: CLLocation, searchDistance: CLLocationDistance = SpatialDataContext.initialPOISearchDistance) -> SpatialDataViewProtocol? {
        var results: SpatialDataView?
        
        dispatchQueue.sync {
            let tile = VectorTile.tileForLocation(location, zoom: SpatialDataContext.zoomLevel)
            
            // Ensure we at least have the current tile and the user's current location
            guard SpatialDataContext.isCached(tile: tile) else {
                return
            }
            
            // TODO: If tiles to load haven't changed, and we are still on the same thread, return the previous view
            
            results = SpatialDataView(location: location,
                                      range: searchDistance,
                                      zoom: SpatialDataContext.zoomLevel,
                                      geolocation: geolocationManager,
                                      motionActivity: motionActivityContext,
                                      destinationManager: destinationManager)
        }
        
        return results
    }
    
    func getCurrentDataView(searchDistance: CLLocationDistance = SpatialDataContext.initialPOISearchDistance) -> SpatialDataViewProtocol? {
        guard let location = currentLocation else {
            return nil
        }
        
        return getDataView(for: location, searchDistance: searchDistance)
    }
    
    func getCurrentDataView(initialSearchDistance: CLLocationDistance = SpatialDataContext.initialPOISearchDistance, shouldExpandDataView: (SpatialDataViewProtocol) -> Bool) -> SpatialDataViewProtocol? {
        // Fetch cached data
        var expansions = 0
        var range = initialSearchDistance
        var dataView = AppContext.shared.spatialDataContext.getCurrentDataView(searchDistance: range)
        
        // Load Nearby
        //
        // Progressively expand search distance until 50 results are returned of
        // seach distance reaches `cacheDistance`.
        while range <= SpatialDataContext.cacheDistance {
            defer {
                range += SpatialDataContext.expansionPOISearchDistance
            }
            
            // Get the spatial data view and filter POIs into quadrants
            dataView = AppContext.shared.spatialDataContext.getCurrentDataView(searchDistance: range)
            
            guard let dataView = dataView else {
                return nil
            }
            
            if shouldExpandDataView(dataView) {
                expansions += 1
                continue
            }
            
            break
        }
        
        return dataView
    }
    
    func checkServiceConnection(completionHandler: @escaping (_ success: Bool) -> Void) {
        guard let tile = currentTile else {
            completionHandler(false)
            return
        }
        
        serviceModel.getTileData(tile: tile, categories: [:], queue: networkQueue) { (statusCode, data, error) in
            // Make sure we don't encounter errors and successfully got the tile
            guard error == nil, statusCode == .notModified || (statusCode == .success && data != nil) else {
                completionHandler(false)
                return
            }
            
            completionHandler(true)
        }
    }
    
    private func scheduleErrorRecovery() {
        
        errorRecoveryTask = DispatchWorkItem { [weak self] in
            guard let `self` = self else { return }
            
            guard let location = self.currentLocation, self.deviceContext.isNetworkConnectionAvailable else {
                self.scheduleErrorRecovery()
                return
            }
            
            GDLogAppVerbose("RECOVERY: Running network error recovery. Attempting to download data.")
            
            self.updateSpatialDataAsync(location: location)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + errorRecoveryDelay, execute: errorRecoveryTask!)
    }
    
    func updateSpatialData(at location: CLLocation, completion: @escaping () -> Void) -> Progress? {
        let dispatchGroup = DispatchGroup()
        let progress = updateSpatialDataAsync(location: location, overridePrioritizeCurrent: false, dispatchGroup: dispatchGroup)
        
        if let progress = progress {
            dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                completion()
            })
            
            return progress
        } else {
            // If data for the given location is already cached,
            // return immediately
            completion()
            return nil
        }
    }
    
    @discardableResult
    fileprivate func updateSpatialDataAsync(location: CLLocation, reloadPORs: Bool = false, overridePrioritizeCurrent: Bool? = nil, dispatchGroup: DispatchGroup? = nil) -> Progress? {
        let current = VectorTile.tileForLocation(location, zoom: SpatialDataContext.zoomLevel)
        let currentCached = SpatialDataContext.isCached(tile: current)
        
        let prioritize = overridePrioritizeCurrent ?? (!currentCached && !reloadPORs)
        let request: (id: UUID, tiles: [VectorTile])? = dispatchQueue.sync(flags: .barrier) {
            if let trackedStore, !StorageContext.shared.isCurrentSpatialStore(trackedStore) {
                invalidateTrackedTiles()
            }
            guard !fetchingTiles else { return nil }
            guard let store = try? StorageContext.shared.spatial() else {
                state = .error
                return nil
            }
            trackedStore = store
            updateFilter.update(location: location)
            let (remaining, missing) = Self.checkForTiles(location: location, tiles: tiles,
                                                          includePORs: reloadPORs, prioritizeCurrent: prioritize)
            tiles = remaining
            tileRequestID = UUID()
            fetchingTiles = !missing.isEmpty
            canceledTilesCount = 0
            expectedTilesCount = remaining.count + missing.count
            originalRequestLocation = location
            state = missing.isEmpty ? .ready : .loading
            return (tileRequestID, missing)
        }

        guard let request else {
            if currentCached { notifyLocationUpdated(location) }
            return nil
        }
        guard !request.tiles.isEmpty else {
            notifyLocationUpdated(location)
            return nil
        }
        if !request.tiles.contains(current) { notifyLocationUpdated(location) }

        let progress = Progress(totalUnitCount: Int64(request.tiles.count))
        request.tiles.forEach { _ in dispatchGroup?.enter() }
        networkQueue.async {
            for tile in request.tiles {
                if Self.needsFetching(tile: tile) {
                    self.fetchTile(tile, requestID: request.id, prioritize: prioritize,
                                   dispatchGroup: dispatchGroup, progress: progress)
                } else {
                    self.finishTile(tile, requestID: request.id, prioritize: prioritize,
                                    dispatchGroup: dispatchGroup, progress: progress)
                }
            }
        }
        return progress
    }

    private func fetchTile(_ tile: VectorTile, requestID: UUID, prioritize: Bool, retryCount: Int = 0,
                           dispatchGroup: DispatchGroup?, progress: Progress) {
        let finish: (Error?) -> Void = { error in
            self.finishTile(tile, requestID: requestID, prioritize: prioritize, retryCount: retryCount,
                            error: error, dispatchGroup: dispatchGroup, progress: progress)
        }

        guard let store = dispatchQueue.sync(execute: { tileRequestID == requestID ? trackedStore : nil }),
              StorageContext.shared.isCurrentSpatialStore(store) else {
            progress.completedUnitCount += 1
            dispatchGroup?.leave()
            return
        }
        do {
            guard let categories = superCategories else { throw SpatialDataContextError.noCategories }
            let epoch = try dispatchQueue.sync {
                guard tileRequestID == requestID else { throw SpatialStorageError.invalidatedFetch }
                return try store.epoch()
            }
            serviceModel.getTileData(tile: tile, categories: categories, queue: networkQueue) { status, data, error in
                self.networkQueue.async {
                    do {
                        if let error { throw error }
                        switch status {
                        case .success:
                            guard let data else { throw SpatialDataContextError.missingData }
                            try store.replace(key: tile.quadKey, metadata: data.metadata,
                                              features: data.featuresForStorage(), epoch: epoch)
                        case .notModified:
                            try store.extend(key: tile.quadKey, expiry: ParsedTile.expiry(), epoch: epoch)
                        case .unknown:
                            throw SpatialDataContextError.missingData
                        }
                        finish(nil)
                    } catch {
                        Self.recoverSpatialStore(store, after: error)
                        finish(error)
                    }
                }
            }
        } catch {
            Self.recoverSpatialStore(store, after: error)
            finish(error)
        }
    }

    private static func recoverSpatialStore(_ store: SpatialTileStore, after error: Error) {
        guard SpatialTileStore.isRebuildable(error) else { return }
        do {
            _ = try StorageContext.shared.recoverSpatialStore(store, after: error)
        } catch {
            GDLogSpatialDataError("Unable to recover spatial database: \(error)")
        }
    }

    private func finishTile(_ tile: VectorTile, requestID: UUID, prioritize: Bool, retryCount: Int = 0,
                            error: Error? = nil, dispatchGroup: DispatchGroup?, progress: Progress) {
        if error != nil, retryCount < 2, dispatchQueue.sync(execute: { tileRequestID == requestID }) {
            fetchTile(tile, requestID: requestID, prioritize: prioritize, retryCount: retryCount + 1,
                      dispatchGroup: dispatchGroup, progress: progress)
            return
        }

        let result: (location: CLLocation?, finished: Bool)? = dispatchQueue.sync(flags: .barrier) {
            guard tileRequestID == requestID, let trackedStore,
                  StorageContext.shared.isCurrentSpatialStore(trackedStore) else { return nil }
            let isCurrent = tile == currentTile
            if let error {
                GDLogSpatialDataError("Unable to fetch tile \(tile.quadKey): \(error)")
                canceledTilesCount += 1
                if isCurrent, !Self.isCached(tile: tile) { state = .error }
            } else {
                tiles.insert(tile)
            }
            let finished = expectedTilesCount == tiles.count + canceledTilesCount
            if finished {
                fetchingTiles = false
                if state != .error { state = .ready }
            }
            let location = (finished || (isCurrent && error == nil)) ? currentLocation ?? originalRequestLocation : nil
            return (location, finished)
        }

        progress.completedUnitCount += 1
        dispatchGroup?.leave()
        if let result, let location = result.location {
            notifyLocationUpdated(location, tilesChanged: true)
            if result.finished && prioritize && error == nil {
                updateSpatialDataAsync(location: location)
            }
        }
    }

    fileprivate func notifyLocationUpdated(_ location: CLLocation, tilesChanged: Bool = false) {
        DispatchQueue.main.async {
            AppContext.process(LocationUpdatedEvent(location))
            
            NotificationCenter.default.post(name: Notification.Name.locationUpdated,
                                            object: self,
                                            userInfo: [SpatialDataContext.Keys.location: location])
            
            if tilesChanged {
                NotificationCenter.default.post(name: Notification.Name.tilesDidUpdate, object: self, userInfo: nil)
            }
        }
    }
    
    @objc private func onNetworkConnectionDidChange(_ notification: NSNotification) {
        guard AppContext.shared.state == .normal else {
            return
        }
        
        guard let isNetworkConnectionAvailable = notification.userInfo?[UIDeviceManager.Keys.isNetworkAvailable] as? Bool else {
            return
        }
        
        if isNetworkConnectionAvailable == true {
            // When the type of internet connection changes (WiFi or Cellular), kick off
            // a new spatial data update. This should help solve edge cases when the user
            // purposefully turns off wifi when having wifi network authentication issues
            guard let location = currentLocation else {
                return
            }
            
            errorRecoveryTask?.cancel()
            
            updateSpatialDataAsync(location: location)
        }
    }
    
    // MARK: - Class Methods
    
    /// Checks if the tile is in the cache
    /// - Parameter tile: The VectorTile to check for
    private class func isCached(tile: VectorTile) -> Bool {
        do {
            return try StorageContext.shared.withSpatialStore { try $0.metadata(for: tile.quadKey) } != nil
        } catch {
            GDLogSpatialDataError("Unable to check tile availability: \(error)")
            return false
        }
    }

    private class func needsFetching(tile: VectorTile) -> Bool {
        do {
            guard let metadata = try StorageContext.shared.withSpatialStore({ try $0.metadata(for: tile.quadKey) }) else {
                return true
            }
            return metadata.expiry <= Date()
        } catch {
            GDLogSpatialDataError("Unable to check tile expiry: \(error)")
            return true
        }
    }

    /// Given the user's location and the current set of tiles we have loaded and are tracking, this
    /// method returns the remaining set of tiles we should continue to track, and the list of new
    /// tiles we need to download.
    ///
    /// - Parameters:
    ///   - location: User's current location
    ///   - tiles: The set of tiles currently downloaded around the user
    /// - Returns: The set of tiles currently downloaded that should still be tracked, and a list of new tiles to download and track.
    public class func checkForTiles(location: CLLocation, tiles: Set<VectorTile>, includePORs: Bool, prioritizeCurrent: Bool = false) -> (Set<VectorTile>, [VectorTile]) {
        guard !prioritizeCurrent else {
            var needed = [VectorTile.tileForLocation(location, zoom: SpatialDataContext.zoomLevel)]
            
            if includePORs {
                needed = Array(SpatialDataCache.tiles(forDestinations: true, forReferences: true, at: zoomLevel).union(needed))
            }
            
            return (Set<VectorTile>(), needed)
        }
        
        var neededTiles = VectorTile.tilesForRegion(location, radius: SpatialDataContext.cacheDistance, zoom: SpatialDataContext.zoomLevel)
        
        if includePORs {
            neededTiles = Array(SpatialDataCache.tiles(forDestinations: true, forReferences: true, at: zoomLevel).union(neededTiles))
        }
        
        let remainingTiles = Set(tiles.filter { neededTiles.contains($0) }) // Remove tile we don't need anymore
        let missingTiles = neededTiles.filter { !remainingTiles.contains($0) } // Get the tiles we need but don't have
        
        return (remainingTiles, missingTiles)
    }
    
    private class func expireAllTiles() {
        do {
            try StorageContext.shared.spatial().expireAll(at: Date(timeIntervalSinceNow: -1))
        } catch {
            GDLogSpatialDataError("Unable to expire the spatial cache: \(error)")
        }
    }

    private class func loadDefaultCategories() -> SuperCategories? {
        GDLogAppInfo("Loading default super categories")
        
        guard let path = Bundle.main.path(forResource: "categories", ofType: "json") else {
            GDLogAppError("Soundscape must have categories! Couldn't load default categories")
            return nil
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            GDLogAppError("Soundscape must have categories! Couldn't load default categories")
            return nil
        }
        
        guard let (version, categories) = SuperCategory.parseCategories(from: data) else {
            GDLogAppError("Soundscape must have categories! Couldn't parse default categories")
            return nil
        }
        
        guard categories.count > 0 else {
            GDLogAppError("Soundscape must have categories! There must be 1 or more default categories")
            return nil
        }
        
        // Get the current version of the categories file
        let currentVersion = UserDefaults.standard.integer(forKey: Keys.categoriesVersion)
        
        guard currentVersion != 0 else {
            // This is the first time the file has been read. Save the version number.
            UserDefaults.standard.set(version, forKey: Keys.categoriesVersion)
            return categories
        }
        
        // Check if the version has changed
        if currentVersion != version {
            // The version has changed, expire tiles to make sure they reload with appropriately assigned super categories
            UserDefaults.standard.set(version, forKey: Keys.categoriesVersion)
            expireAllTiles()
        }
        
        return categories
    }
        
}

extension SpatialDataContext: GeolocationManagerUpdateDelegate {
    
    func didUpdateLocation(_ location: CLLocation) {
        currentLocation = location
        
        AppContext.shared.audioEngine.updateUserLocation(location)
        
        guard superCategories != nil else {
            GDLogSpatialDataVerbose("Location updated - Skipping data update (super categories nil)")
            notifyLocationUpdated(location)
            return
        }
        
        if state == .waitingForLocation {
            // We have a location now so we shouldn't be waiting in this state any more
            state = .ready
        }
        
        guard deviceContext.isNetworkConnectionAvailable && updateFilter.shouldUpdate(location: location) else {
            // This case is very common, so we don't output a log statement here...
            notifyLocationUpdated(location)
            return
        }
        
        updateSpatialDataAsync(location: location)
    }
    
}
