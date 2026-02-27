//
//  GPXSimulator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import CoreGPX
import SSGeo

struct GPXIndex {
    static let zero = GPXIndex(track: 0, segment: 0, point: 0)
    
    var track: Int
    var segment: Int
    var point: Int
    
    func nextPoint() -> GPXIndex {
        return GPXIndex(track: track, segment: segment, point: point+1)
    }
    
    func nextSegment() -> GPXIndex {
        return GPXIndex(track: track, segment: segment+1, point: 0)
    }
    
    func nextTrack() -> GPXIndex {
        return GPXIndex(track: track+1, segment: 0, point: 0)
    }
    
    func indexByAddingPoints(_ points: Int) -> GPXIndex {
        return GPXIndex(track: track, segment: segment, point: point+points)
    }
}

// MARK: -

@MainActor
class GPXSimulator {
    
    // MARK: Types
    
    private struct MetadataKeyword {
        static let activityStationary = "activity:stationary"
        static let activityWalking = "activity:walking"
        static let activityAutomotive = "activity:automotive"
        static let transformAverageWalkingSpeed = "transform:average_walking_speed"
        static let timeInterval = "time_interval"
    }

    private struct SimulatorLocation {
        var location: CLLocation
        let deviceHeading: Double?
    }

    private enum GPXTag {
        static let speed = "speed"
        static let course = "course"

        static let garminTrackPointExtension = "gpxtpx:TrackPointExtension"
        static let garminSpeed = "gpxtpx:speed"
        static let garminCourse = "gpxtpx:course"

        static let soundscapeTrackPointExtension = "gpxgd:TrackPointExtension"
        static let soundscapeHorizontalAccuracy = "gpxgd:hor_acc"
        static let soundscapeVerticalAccuracy = "gpxgd:ver_acc"
        static let soundscapeTrueHeading = "gpxgd:hdg_tru"
        static let soundscapeMagneticHeading = "gpxgd:hdg_mag"
        static let soundscapeHeadingAccuracy = "gpxgd:hdg_acc"
        static let soundscapeDeviceHeading = "gpxgd:hdg_dvc"
    }
    
    struct AudioConfiguration {
        let filename: String
        let pauseWithSimulation: Bool
        let volume: Float
    }

    // MARK: Constants

    /// Default time interval to use between simulated locations when timestamps are not present
    static let defaultTimeIntervalBetweenLocations: TimeInterval = 1.0
    private static let missingTimestampIdentifier = Date(timeIntervalSince1970: 0)
    
    // MARK: - Properties
    
    /// Identifier for the SensorProvider protocol
    let id: UUID = .init()
    
    private var significantChangeMonitoringOrigin: SignificantChangeMonitoringOrigin?
    // Provider Delegates
    weak var locationDelegate: LocationProviderDelegate?
    weak var headingDelegate: DeviceHeadingProviderDelegate?
    weak var courseDelegate: RawCourseProviderDelegate?
    // Simulator State
    let isBackgroundExecutionEnabled = true
    private(set) var isSimulating = false
    private var isLocationActive = false
    private var isCourseActive = false
    private var isDeviceHeadingActive = false
    private(set) var isPaused = false // Only relevant if a simulation is in progress
    private(set) var activity: String?
    private var currentIndex = GPXIndex.zero
    private var didReachSimulationEnd = false
    private var simulatedLocationTimer: Timer?
    
    /// If locations has no course values, they will be generated from the bearing
    /// of every location to the next.
    /// - Note: Course will be synthesize only if there are more than 1 location
    /// - Note: Course will be synthesize only if locations do not have the openscape GPX extention,
    /// as they already should have the course, even if it's invalid (`-1`).
    private var synthesizeCourse = true
    
    /// If locations have no speed or timestamp values, they will be automatically synthesized with `timeIntervalBetweenLocations`.
    /// - Note: The first location's speed will be 0.0
    private var synthesizeSpeed = true

    /// If locations have no timestamp values, we use this value between location updates
    private var timeIntervalBetweenLocations = defaultTimeIntervalBetweenLocations

    /// The audio player for the the optional background audio
    private var audioPlayer: FadeableAudioPlayer?

    let gpx: GPXRoot
    
    var audioConfiguration: AudioConfiguration? {
        didSet {
            setupAudioPlayer()
        }
    }
    
    // MARK: Computed Properties
    
    var allTrackPoints: [GPXTrackPoint]? {
        var trackPoints: [GPXTrackPoint] = []
        
        for track in gpx.tracks {
            for segment in track.segments {
                for point in segment.points {
                    trackPoints.append(point)
                }
            }
        }
        
        return trackPoints
    }
    
    var allTrackLocations: [CLLocation]? {
        guard let tracks = allTrackPoints else { return nil }
        return tracks.map { simulatorLocation(for: $0).location }
    }
    
    // MARK: - Initialization
    
    init?(gpx: GPXRoot) {
        // Check if file has any data
        guard let firstTrack = gpx.tracks.first,
            let firstSegment = firstTrack.segments.first,
            firstSegment.points.first != nil else {
                return nil
        }
        
        self.gpx = gpx
        
        if let keywords = gpx.metadata?.keywords {
            process(metadataKeywords: keywords)
        }
        
        // If no activity is specified, default to walking
        if activity == nil {
            activity = ActivityType.walking.rawValue
        }
    }

    convenience init?(filepath: String) {
        guard let gpx = GPXParser(withPath: filepath)?.parsedData() else {
            return nil
        }
        
        self.init(gpx: gpx)
    }
    
    private func process(metadataKeywords keywords: String) {
        if keywords.contains(MetadataKeyword.activityStationary) {
            activity = ActivityType.stationary.rawValue
        } else if keywords.contains(MetadataKeyword.activityWalking) {
            activity = ActivityType.walking.rawValue
        } else if keywords.contains(MetadataKeyword.activityAutomotive) {
            activity = ActivityType.automotive.rawValue
        }
        
        if keywords.contains(MetadataKeyword.timeInterval) {
            // Extract the time interval number
            // Keyword format: "time_interval:1.4"
            
            let scanner = Scanner(string: keywords)
            
            let prefix = MetadataKeyword.timeInterval + ":"

            if scanner.scanUpToString(prefix) != nil,
               scanner.scanString(prefix) != nil,
               let timeInterval = scanner.scanDouble() {
                timeIntervalBetweenLocations = timeInterval
            }
        }
    }
    
    private func setupAudioPlayer() {
        guard let audioConfiguration = audioConfiguration else {
            audioPlayer = nil
            return
        }
        
        guard let player = FadeableAudioPlayer.fadeablePlayer(with: audioConfiguration.filename) else {
            audioPlayer = nil
            GDLogAppError("GPXSimulator - audio error: file not found.")
            return
        }
        
        player.numberOfLoops = -1 // Play indefinitely
        player.volume = audioConfiguration.volume
        
        audioPlayer = player
    }
    
    // MARK: Manage Simulator
    
    private func start() {
        reset()
        
        isSimulating = true
        
        audioPlayer?.fadeIn()
        
        startSimulatingActivity()

        simulateLocation(at: currentIndex)
    }
    
    private func stop() {
        reset()
        
        audioPlayer?.stop()
        
        stopSimulatingActivity()
    }
    
    private func startSimulatingActivity() {
        guard let activity = activity,
            let motionActivity = ActivityType(rawValue: activity) else { return }
        
        AppContext.shared.motionActivityContext.gpxSimulatedActivity = motionActivity
    }
    
    private func stopSimulatingActivity() {
        AppContext.shared.motionActivityContext.gpxSimulatedActivity = nil
    }
    
    func startLocationUpdates() {
        guard isLocationActive == false else {
            return
        }
        
        isLocationActive = true
        
        // If we are already simulating,
        // we do not need to do anything
        guard isSimulating == false else {
            return
        }
        
        // Start simulating
        start()
    }
    
    func stopLocationUpdates() {
        guard isLocationActive else {
            return
        }
        
        isLocationActive = false
        
        // If we are still collecting course or device heading updates,
        // do not stop the simulator
        guard isCourseActive == false, isDeviceHeadingActive == false else {
            return
        }
        
        // Stop simulating
        stop()
    }
    
    func startCourseProviderUpdates() {
        guard isCourseActive == false else {
            return
        }
        
        isCourseActive = true
        
        // If we are already simulating,
        // we do not need to do anything
        guard isSimulating == false else {
            return
        }
        
        // Start simulating
        start()
    }
    
    func stopCourseProviderUpdates() {
        guard isCourseActive else {
            return
        }
        
        isCourseActive = false
        
        // If we are still collecting location or device heading updates,
        // do not stop the simulator
        guard isLocationActive == false, isDeviceHeadingActive == false else {
            return
        }
        
        // Stop simulating
        stop()
    }
    
    func startDeviceHeadingUpdates() {
        guard isDeviceHeadingActive == false else {
            return
        }
        
        isDeviceHeadingActive = true
        
        // If we are already simulating,
        // we do not need to do anything
        guard isSimulating == false else {
            return
        }
        
        // Start simulating
        start()
    }
    
    func stopDeviceHeadingUpdates() {
        guard isDeviceHeadingActive else {
            return
        }
        
        isDeviceHeadingActive = false
        
        // If we are still collecting location or course updates,
        // do not stop the simulator
        guard isLocationActive == false, isCourseActive == false else {
            return
        }
        
        // Stop simulating
        stop()
    }
    
    // MARK: Location Updates
    
    func simulateLocation(at index: GPXIndex) {
        guard isSimulating else {
            return
        }
        
        guard let location = self.location(at: index) else {
            GDLogLocationInfo("Simulated location index is out of bounds")
            return
        }
        
        if let origin = significantChangeMonitoringOrigin {
            // Do not propogate location update if there is no
            // significant change
            guard origin.shouldUpdateLocation(location.location) else {
                clearNextSimulatedLocationTimer()
                currentIndex = index
                scheduleNextSimulatedLocation()
                return
            }
        }
        
        // If we reached the end of a simulation, the activity resets to "stationary"
        // We need to re-activate the simulated activity
        if didReachSimulationEnd {
            didReachSimulationEnd = false
            startSimulatingActivity()
        }
        
        clearNextSimulatedLocationTimer()
        currentIndex = index
        
        var deviceHeading: HeadingValue?
        
        if let lDeviceHeading = location.deviceHeading, lDeviceHeading >= 0.0, lDeviceHeading < 360.0 {
            // Simulated device heading is valid
            deviceHeading = HeadingValue(lDeviceHeading, nil)
        }
        
        var course: HeadingValue?
        if location.location.course >= 0.0 {
            // Simulated course is valid
            course = HeadingValue(location.location.course, nil)
        }
        
        // If location updates are enabled,
        // propogate location update
        if isLocationActive {
            locationDelegate?.locationProvider(self, didUpdateLocation: location.location)
        }
        
        // If course updates are enabled,
        // propogate course update
        if isCourseActive {
            courseDelegate?.courseProvider(self, didUpdateCourse: course, speed: nil)
        }
        
        // If device heading updates are enabled,
        // propogate device heading update
        if isDeviceHeadingActive {
            headingDelegate?.deviceHeadingProvider(self, didUpdateDeviceHeading: deviceHeading)
        }
        
        scheduleNextSimulatedLocation()
    }
    
    private func scheduleNextSimulatedLocation() {
        guard isSimulating, !isPaused else {
            return
        }
        
        guard let nextIndex = indexByJumpingPoints(currentIndex, pointsToJump: 1) else {
            reachedSimulationEnd()
            return
        }
        
        guard let gpxLocation = self.location(at: currentIndex),
            let nextGpxLocation = self.location(at: nextIndex) else {
                reachedSimulationEnd()
                return
        }
        
        // Create a timer to simulate the next location
        
        // Calculate the time interval between the current and next location update
        let timeInterval = nextGpxLocation.location.timestamp.timeIntervalSince(gpxLocation.location.timestamp)
        let fireDate: Date
        
        // Check if the current and next locations contain a valid timestamp.
        // Also, check if the time interval between the location updates is valid.
        if timeInterval >= timeIntervalBetweenLocations {
            fireDate = Date(timeIntervalSinceNow: timeInterval)
        } else {
            // The locations do not contain valid timestamps, use the default time interval between updates
            fireDate = Date(timeIntervalSinceNow: timeIntervalBetweenLocations)
        }
        
        simulatedLocationTimer = Timer(fireAt: fireDate,
                                       interval: 0.0,
                                       target: self,
                                       selector: #selector(simulateNextLocation),
                                       userInfo: nil,
                                       repeats: false)
        
        RunLoop.current.add(simulatedLocationTimer!, forMode: .common)
    }
    
    private func reachedSimulationEnd() {
        GDLogLocationInfo("Reached end of simulated locations")

        didReachSimulationEnd = true
        AppContext.shared.motionActivityContext.gpxSimulatedActivity = ActivityType.stationary
    }
    
    // MARK: Simulation state
    
    func toggleSimulationState() {
        if isPaused {
            resumeSimulation()
        } else {
            pauseSimulation()
        }
    }
    
    private func pauseSimulation() {
        guard isSimulating else {
            return
        }
        
        isPaused = true
        clearNextSimulatedLocationTimer()
        
        if audioConfiguration?.pauseWithSimulation ?? false {
            audioPlayer?.pause()
        }
    }
    
    private func resumeSimulation() {
        guard isSimulating else {
            return
        }
        
        isPaused = false
        simulateNextLocation()
        
        if audioConfiguration?.pauseWithSimulation ?? false {
            audioPlayer?.play()
        }
    }
    
    private func reset() {
        clearNextSimulatedLocationTimer()
        
        isSimulating = false
        isPaused = false
        currentIndex = GPXIndex.zero
        didReachSimulationEnd = false
    }
    
    private func clearNextSimulatedLocationTimer() {
        guard let timer = simulatedLocationTimer, timer.isValid else {
            return
        }
        
        timer.invalidate()
        simulatedLocationTimer = nil
    }
    
    // MARK: Jump Index

    func simulatePreviousLocation() {
        simulateJumpBack(numberOfLocations: 1)
    }
    
    @objc func simulateNextLocation() {
        simulateJumpForward(numberOfLocations: 1)
    }
    
    func simulateJumpBack(numberOfLocations: Int) {
        simulateJump(numberOfLocations: -numberOfLocations)
    }
    
    func simulateJumpForward(numberOfLocations: Int) {
        simulateJump(numberOfLocations: numberOfLocations)
    }
    
    func simulateJump(numberOfLocations: Int) {
        guard isSimulating else {
            return
        }
        
        guard let nextIndex = indexByJumpingPoints(currentIndex, pointsToJump: numberOfLocations) else {
            reachedSimulationEnd()
            return
        }

        simulateLocation(at: nextIndex)
    }
    
    // MARK: Helpers
    
    /// If the jump lands on the next or previous segment or track, it will return 0 as the point
    private func indexByJumpingPoints(_ index: GPXIndex, pointsToJump: Int) -> GPXIndex? {
        let track = gpx.tracks[currentIndex.track]
        let segment = track.segments[currentIndex.segment]
        
        if currentIndex.point + pointsToJump < 0 {
            // Jump back to segment start
            return GPXIndex(track: currentIndex.track, segment: currentIndex.segment, point: 0)
        } else if currentIndex.point + pointsToJump < segment.points.count {
            // Still inside current segment
            return currentIndex.indexByAddingPoints(pointsToJump)
        } else if currentIndex.segment < track.segments.count-1 {
            // Next segment
            return currentIndex.nextSegment()
        } else if currentIndex.track == gpx.tracks.count-1 {
            // Next Track
            return currentIndex.nextTrack()
        }
        
        // Needed index is out of bounds
        return nil
    }
    
    private func trackPoint(at index: GPXIndex) -> GPXTrackPoint? {
        guard index.track >= 0 && index.track < gpx.tracks.count else {
            return nil
        }
        
        let track = gpx.tracks[index.track]
        guard index.segment >= 0 && index.segment < track.segments.count else {
            return nil
        }
        
        let segment = track.segments[index.segment]
        guard index.point >= 0 && index.point < segment.points.count else {
            return nil
        }
        
        let point = segment.points[index.point]
        return point
    }
    
    private func location(at index: GPXIndex) -> SimulatorLocation? {
        guard let trackPoint = trackPoint(at: index) else { return nil }
        var simulatorLocation = simulatorLocation(for: trackPoint)
        
        // Synthesize the course if needed
        if !isValidDirection(simulatorLocation.location.course) && synthesizeCourse && !hasSoundscapeExtension(trackPoint) {
            let course = self.course(for: index)
            if isValidDirection(course) {
                simulatorLocation.location = updatedLocation(simulatorLocation.location, course: course)
            }
        }
        
        // Synthesize the speed if needed
        if !isValidSpeed(simulatorLocation.location.speed) && synthesizeSpeed && !hasSoundscapeExtension(trackPoint) {
            if let speed = self.speed(for: index), isValidSpeed(speed) {
                simulatorLocation.location = updatedLocation(simulatorLocation.location, speed: speed)
            }
        }
        
        return simulatorLocation
    }
    
    private func course(for index: GPXIndex) -> CLLocationDirection {
        guard let trackPoint = self.trackPoint(at: index) else { return -1 }
        
        // Try to get existing track course
        if let trackCourseStr = trackPoint.extensions?.children.first(where: { $0.name == GPXTag.course })?.text,
           let trackCourse = CLLocationDirection(trackCourseStr),
           isValidDirection(trackCourse) {
            // I am like 95% sure the previous code here meant the extensions course, but if that breaks you might want to look here first.
            return trackCourse
        }
        
        if let garminExtensions = extensionElement(named: GPXTag.garminTrackPointExtension, in: trackPoint.extensions),
           let trackCourseStr = childText(in: garminExtensions, named: GPXTag.garminCourse),
           let trackCourse = CLLocationDirection(trackCourseStr),
           isValidDirection(trackCourse) {
            return trackCourse
        }
        
        // Calculate course
        let trackPoints = self.trackPoints(trackIndex: index.track, segmentIndex: index.segment)
        let isLastTrackPoint = (index.point == trackPoints.count-1)
        
        if isLastTrackPoint {
            // Last track point, use the previous location's course.
            let prevIndex = GPXIndex(track: index.track, segment: index.segment, point: index.point-1)
            return course(for: prevIndex)
        }
        
        let nextIndex = GPXIndex(track: index.track, segment: index.segment, point: index.point+1)
        guard let nextTrackPoint = self.trackPoint(at: nextIndex) else { return -1 }
        
        if trackPoint.latitude == nextTrackPoint.latitude &&
            trackPoint.longitude == nextTrackPoint.longitude {
            // If the next coordinate is equal to the current one, use the previous location's course.
            let prevIndex = GPXIndex(track: index.track, segment: index.segment, point: index.point-1)
            return course(for: prevIndex)
        }
    
        return bearing(
            from: simulatorLocation(for: trackPoint).location.coordinate,
            to: simulatorLocation(for: nextTrackPoint).location.coordinate
        )
    }

    private func speed(for index: GPXIndex) -> CLLocationSpeed? {
        guard let trackPoint = self.trackPoint(at: index) else {
            return nil
        }
        
        // Try to get the existing speed value
        if let trackSpeedStr = trackPoint.extensions?.children.first(where: { $0.name == GPXTag.speed })?.text,
           let trackSpeed = CLLocationSpeed(trackSpeedStr),
           isValidSpeed(trackSpeed) {
            // I am like 95% sure the previous code here meant the extensions speed, but if that breaks you might want to look here first.
            return trackSpeed
        }
        
        if let garminExtensions = extensionElement(named: GPXTag.garminTrackPointExtension, in: trackPoint.extensions),
            let trackSpeedStr = childText(in: garminExtensions, named: GPXTag.garminSpeed),
            let trackSpeed = CLLocationSpeed(trackSpeedStr),
            isValidSpeed(trackSpeed) {
            return trackSpeed
        }
        
        // Calculate speed
        if index.point == 0 {
            // First track point, use zero.
            return 0.0
        }
        
        let prevIndex = GPXIndex(track: index.track, segment: index.segment, point: index.point-1)
        guard let prevTrackPoint = self.trackPoint(at: prevIndex) else {
            return nil
        }
        
        guard let currentLatitude = trackPoint.latitude, let currentLongitude = trackPoint.longitude,
              let prevLatitude = prevTrackPoint.latitude, let prevLongitude = prevTrackPoint.longitude else {
            return nil
        }
        let location = CLLocation(latitude: currentLatitude, longitude: currentLongitude)
        let prevLocation = CLLocation(latitude: prevLatitude, longitude: prevLongitude)
        
        let distance = coordinateDistance(from: location.coordinate, to: prevLocation.coordinate)
        let time = timeIntervalBetweenLocations
        
        return distance/time
    }
    
    func index(for trackPoint: GPXTrackPoint) -> GPXIndex? {
        for (trackIndex, track) in gpx.tracks.enumerated() {
            for (segmentIndex, segment) in track.segments.enumerated() {
                for (pointIndex, point) in segment.points.enumerated() where point === trackPoint {
                    return GPXIndex(track: trackIndex, segment: segmentIndex, point: pointIndex)
                }
            }
        }
        
        return nil
    }
    
    private func trackPoints(trackIndex: Int, segmentIndex: Int? = nil) -> [GPXTrackPoint] {
        if let segmentIndex = segmentIndex {
            return gpx.tracks[trackIndex].segments[segmentIndex].points
        }
        
        var trackPoints: [GPXTrackPoint] = []
        for trackSegment in gpx.tracks[trackIndex].segments {
            trackPoints.append(contentsOf: trackSegment.points)
        }
        
        return trackPoints
    }
    
    func closestTrackPoint(to location: CLLocation) -> GPXTrackPoint? {
        guard let allTrackPoints = allTrackPoints else { return nil }
        
        var closestTrackPoint: GPXTrackPoint?
        var closestDistance: CLLocationDistance = CLLocationDistanceMax

        for trackPoint in allTrackPoints {
            let distance = coordinateDistance(
                from: location.coordinate,
                to: simulatorLocation(for: trackPoint).location.coordinate
            )
            if distance > closestDistance {
                continue
            }
            
            closestTrackPoint = trackPoint
            closestDistance = distance
        }
        return closestTrackPoint
    }

    private func extensionElement(named name: String, in extensions: GPXExtensions?) -> GPXExtensionsElement? {
        extensions?.children.first(where: { $0.name == name })
    }

    private func childText(in element: GPXExtensionsElement, named name: String) -> String? {
        element.children.first(where: { $0.name == name })?.text
    }

    private func hasSoundscapeExtension(_ trackPoint: GPXTrackPoint) -> Bool {
        extensionElement(named: GPXTag.soundscapeTrackPointExtension, in: trackPoint.extensions) != nil
    }

    private func isValidDirection(_ direction: CLLocationDirection) -> Bool {
        direction >= 0
    }

    private func isValidSpeed(_ speed: CLLocationSpeed) -> Bool {
        speed >= 0
    }

    private func updatedLocation(_ location: CLLocation, course: CLLocationDirection) -> CLLocation {
        CLLocation(
            coordinate: location.coordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: course,
            speed: location.speed,
            timestamp: location.timestamp
        )
    }

    private func updatedLocation(_ location: CLLocation, speed: CLLocationSpeed) -> CLLocation {
        CLLocation(
            coordinate: location.coordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: speed,
            timestamp: location.timestamp
        )
    }

    private func isValidLocationCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate) &&
            !(coordinate.latitude == 0.0 && coordinate.longitude == 0.0)
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        guard isValidLocationCoordinate(from), isValidLocationCoordinate(to) else {
            return -1
        }

        guard from.latitude != to.latitude || from.longitude != to.longitude else {
            return 0
        }

        return SSGeoMath.initialBearingDegrees(
            from: SSGeoCoordinate(latitude: from.latitude, longitude: from.longitude),
            to: SSGeoCoordinate(latitude: to.latitude, longitude: to.longitude)
        )
    }

    private func coordinateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        SSGeoMath.distanceMeters(
            from: SSGeoCoordinate(latitude: from.latitude, longitude: from.longitude),
            to: SSGeoCoordinate(latitude: to.latitude, longitude: to.longitude)
        )
    }

    private func simulatorLocation(for trackPoint: GPXTrackPoint) -> SimulatorLocation {
        var speed: CLLocationSpeed = -1
        var course: CLLocationDirection = -1

        var horizontalAccuracy: CLLocationAccuracy = -1
        var verticalAccuracy: CLLocationAccuracy = -1

        var trueHeading: CLLocationDirection = -1
        var magneticHeading: CLLocationDirection = -1
        var headingAccuracy: CLLocationDirection = -1

        var deviceHeading: Double?

        // Backwards compatibility: historically these dilution values were used for accuracy.
        horizontalAccuracy = trackPoint.horizontalDilution ?? horizontalAccuracy
        verticalAccuracy = trackPoint.verticalDilution ?? verticalAccuracy

        if let extensions = trackPoint.extensions {
            // Backwards compatibility: older files stored speed/course directly as extension children.
            if let speedText = extensions.children.first(where: { $0.name == GPXTag.speed })?.text,
               let parsedSpeed = CLLocationSpeed(speedText) {
                speed = parsedSpeed
            }
            if let courseText = extensions.children.first(where: { $0.name == GPXTag.course })?.text,
               let parsedCourse = CLLocationDirection(courseText) {
                course = parsedCourse
            }

            if let garminExtensions = extensionElement(named: GPXTag.garminTrackPointExtension, in: extensions) {
                if let garminSpeedText = childText(in: garminExtensions, named: GPXTag.garminSpeed),
                   let parsedSpeed = CLLocationSpeed(garminSpeedText) {
                    speed = parsedSpeed
                }
                if let garminCourseText = childText(in: garminExtensions, named: GPXTag.garminCourse),
                   let parsedCourse = CLLocationDirection(garminCourseText) {
                    course = parsedCourse
                }
            }

            if let soundscapeExtensions = extensionElement(named: GPXTag.soundscapeTrackPointExtension, in: extensions) {
                if let horizontalAccuracyText = childText(in: soundscapeExtensions, named: GPXTag.soundscapeHorizontalAccuracy),
                   let parsedHorizontalAccuracy = CLLocationAccuracy(horizontalAccuracyText) {
                    horizontalAccuracy = parsedHorizontalAccuracy
                }
                if let verticalAccuracyText = childText(in: soundscapeExtensions, named: GPXTag.soundscapeVerticalAccuracy),
                   let parsedVerticalAccuracy = CLLocationAccuracy(verticalAccuracyText) {
                    verticalAccuracy = parsedVerticalAccuracy
                }

                if let trueHeadingText = childText(in: soundscapeExtensions, named: GPXTag.soundscapeTrueHeading),
                   let parsedTrueHeading = CLLocationDirection(trueHeadingText) {
                    trueHeading = parsedTrueHeading
                }
                if let magneticHeadingText = childText(in: soundscapeExtensions, named: GPXTag.soundscapeMagneticHeading),
                   let parsedMagneticHeading = CLLocationDirection(magneticHeadingText) {
                    magneticHeading = parsedMagneticHeading
                }
                if let headingAccuracyText = childText(in: soundscapeExtensions, named: GPXTag.soundscapeHeadingAccuracy),
                   let parsedHeadingAccuracy = CLLocationDirection(headingAccuracyText) {
                    headingAccuracy = parsedHeadingAccuracy
                }
                if let deviceHeadingText = childText(in: soundscapeExtensions, named: GPXTag.soundscapeDeviceHeading),
                   let parsedDeviceHeading = CLLocationDirection(deviceHeadingText) {
                    deviceHeading = parsedDeviceHeading
                }

                // Backwards compatibility for older heading encodings.
                if deviceHeading == nil {
                    if trueHeading >= 0.0 {
                        deviceHeading = trueHeading
                    } else if headingAccuracy >= 0.0 {
                        deviceHeading = magneticHeading
                    }
                }
            }
        }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: trackPoint.latitude!, longitude: trackPoint.longitude!),
            altitude: trackPoint.elevation ?? 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: trackPoint.time ?? Self.missingTimestampIdentifier
        )

        return SimulatorLocation(location: location, deviceHeading: deviceHeading)
    }

}

// MARK: - LocationProvider

extension GPXSimulator: LocationProvider {
    
    func startMonitoringSignificantLocationChanges() -> Bool {
        guard let location = self.location(at: currentIndex)?.location else {
            return false
        }
        
        significantChangeMonitoringOrigin = SignificantChangeMonitoringOrigin(location)
        
        isSimulating = true
        isLocationActive = true
        
        simulateLocation(at: currentIndex)
        
        return true
    }
    
    func stopMonitoringSignificantLocationChanges() {
        significantChangeMonitoringOrigin = nil
        
        isSimulating = false
    }
    
}

// MARK: - RawCourseProvider

extension GPXSimulator: RawCourseProvider { }

// MARK: - DeviceHeadingProvider

extension GPXSimulator: DeviceHeadingProvider { }
