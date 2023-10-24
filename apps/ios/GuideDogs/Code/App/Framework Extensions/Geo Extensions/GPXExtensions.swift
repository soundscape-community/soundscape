//
//  GPXExtensions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import CoreGPX
import CoreMotion.CMMotionActivity

public typealias GPXActivity = String

public struct GPXLocation {
    var location: CLLocation
    var deviceHeading: Double?
    var activity: GPXActivity?
}

extension GPXBounds {
    convenience init?(with locations: [GPXLocation]) {
        guard let firstLocation = locations.first?.location else {
            return nil
        }
        
        var minLatitude = firstLocation.coordinate.latitude
        var maxLatitude = firstLocation.coordinate.latitude
        var minLongitude = firstLocation.coordinate.longitude
        var maxLongitude = firstLocation.coordinate.longitude

        for gpxLocation in locations {
            let location = gpxLocation.location
            
            if location.coordinate.latitude < minLatitude {
                minLatitude = location.coordinate.latitude
            }
            if location.coordinate.latitude > maxLatitude {
                maxLatitude = location.coordinate.latitude
            }
            if location.coordinate.latitude < minLongitude {
                minLongitude = location.coordinate.longitude
            }
            if location.coordinate.latitude > maxLongitude {
                maxLongitude = location.coordinate.longitude
            }
        }
        
        self.init(minLatitude: minLatitude, maxLatitude: maxLatitude,
                  minLongitude: minLongitude, maxLongitude: maxLongitude)
    }
}

extension GPXRoot {
    
    class func defaultRoot() -> GPXRoot {
        let creator = "\(AppContext.appDisplayName) \(AppContext.appVersion) (\(AppContext.appBuild))"
        let root = GPXRoot(creator: creator)
        
        let metadata = GPXMetadata()
        metadata.time = Date()
        metadata.desc = "Created on \(UIDevice.current.model) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion))"
        
        let author = GPXAuthor()
        author.name = UIDevice.current.name
        metadata.author = author
        
        root.metadata = metadata
        
        return root
    }
    
    class func createGPX(withTrackLocations trackLocations: [GPXLocation]) -> GPXRoot {
        let root = GPXRoot.defaultRoot()
        root.metadata?.bounds = GPXBounds(with: trackLocations)
        
        let trackSegment = GPXTrackSegment()
        for gpxLocation in trackLocations {
            trackSegment.add(trackpoint: GPXTrackPoint(with: gpxLocation))
        }
        
        let track = GPXTrack()
        track.add(trackSegment: trackSegment)
        
        root.add(track: track)
        
        return root
    }
}

// MARK: Implement Custom GPX Extensions

extension GPXExtensionsElement {
    /// Sets the first child tag with the specified name, or creates a new one if it does not exist.
    /// If value is `nil`, removes specified tags
    public func set_property(_ name: String, to value: String?) {
        guard let value = value else {
            children.removeAll(where: { $0.name == name })
            return
        }
        if let child = children.first(where: { $0.name == name }) {
            child.text = value
            return
        }
        
        let new_element = GPXExtensionsElement(name: value)
        new_element.text = value
        children.append(new_element)
    }
    
    /// Gets the first child tag with the specified name, or nil if not found
    public func get_property(_ name: String) -> String? {
        return children.first(where: { $0.name == name })?.text
    }
}

enum GPXExtensionsKeys : String {
    case kGPXTrackPointExtensions = "gpxtpx:TrackPointExtension"
    case kGPXTrailsTrackExtensions = "trailsio:TrackExtension"
    case kGPXTrailsTrackPointExtensions = "trailsio:TrackPointExtension"
    case kGPXSoundscapeExtensions = "gpxgd:TrackPointExtension" // why is it called this???????
    case kGPXSoundscapeSharedContentExtensions = "gpxsc:meta"
    case kGPXSoundscapeAnnotationExtensions = "gpxsc:annotations"
    case kGPXSoundscapeLinkExtensions = "gpxsc:links"
    case kGPXSoundscapePOIExtensions = "gpxsc:poi"
}

/// Allows easy access to be provided to extensions
/// However, the generic version does nothing on its own.
/// Instead, each GPX extension has a (swift) extension that defines it
/// (kinda like a fancy inheritance using generics)
class GPXExtensionView<E: RawRepresentable> where E.RawValue == String {
    private weak var ref: GPXExtensionsElement?
    init(_ ref: GPXExtensionsElement) {
        // TODO: maybe add a way to assert/ensure we have matching `ref` tag and `E`
        self.ref = ref
    }
    
    public var still_valid: Bool { return ref != nil }
    
    private func get_single(_ key: E) -> String? {
        return ref?.get_property(key.rawValue)
    }
    /// Allows conversion to string-convertible values such as integral numbers
    private func get_single<T: LosslessStringConvertible>(_ key: E) -> T? {
        guard let value: String = get_single(key) else {
            return nil
        }
        return T(value)
    }
    private func set_single(_ key: E, to value: String?) {
        guard let value = value else {
            return
        }
        ref?.set_property(key.rawValue, to: value)
    }
    /// Allows conversion from string-convertible values such as integral numbers
    private func set_single(_ key: E, to value: LosslessStringConvertible?) {
        guard let value = value else {
            return
        }
        ref?.set_property(key.rawValue, to: String(value))
    }
}
func BuildGPXExtension(_ type: GPXExtensionsKeys) -> GPXExtensionsElement {
    return GPXExtensionsElement(name: type.rawValue)
}

// TODO: Many of the properties in the various extensions are NSNumber in the Objective-C versions. That means they could be any number type, from floating point to integer types to booleans. We should probably figure out what they're actually supposed to be.

/// child tags within a `GPXTrackPointExtensions` which has tag `gpxtpx:TrackPointExtension`
/// - seealso: [](https://www8.garmin.com/xmlschemas/TrackPointExtensionv2.xsd)
enum GPXTrackPointExtensionsProperties : String {
    case kHeartRate = "gpxtpx:hr" // unsigned int
    case kCadence = "gpxtpx:cad" // unsigned int
    case kSpeed = "gpxtpx:speed" // double
    case kCourse = "gpxtpx:course" // double
}
extension GPXExtensionView<GPXTrackPointExtensionsProperties> {
    public var heartRate: UInt? {
        get { get_single(.kHeartRate) }
        set { set_single(.kHeartRate, to: newValue) }
    }
    public var cadence: UInt? {
        get { get_single(.kCadence) }
        set { set_single(.kCadence, to: newValue) }
    }
    public var speed: Double? {
        get { get_single(.kSpeed) }
        set { set_single(.kSpeed, to: newValue) }
    }
    public var course: Double? {
        get { get_single(.kCourse) }
        set { set_single(.kCourse, to: newValue) }
    }
}

/// - seealso: [](https://trails.io/GPX/1/0/trails_1.0.xsd)
enum GPXTrailsTrackExtensionsProperties : String {
    case kElementActivity = "trailsio:activity"
}
extension GPXExtensionView<GPXTrailsTrackExtensionsProperties> {
    public var activityType: String? {
        get { get_single(.kElementActivity) }
        set {set_single(.kElementActivity, to: newValue) }
    }
}

/// - seealso: [](https://trails.io/GPX/1/0/trails_1.0.xsd)
enum GPXTrailsTrackPointExtensionsProperties : String {
    case kElementHorizontalAcc = "trailsio:hacc"
    case kElementVerticalAcc = "trailsio:vacc"
    case kElementSteps = "trailsio:steps"
}
extension GPXExtensionView<GPXTrailsTrackPointExtensionsProperties> {
    public var horizontalAcceleration: Double? {
        get { get_single(.kElementHorizontalAcc) }
        set { set_single(.kElementHorizontalAcc, to: newValue) }
    }
    public var verticalAcceleration: Double? {
        get { get_single(.kElementVerticalAcc) }
        set { set_single(.kElementVerticalAcc, to: newValue) }
    }
    public var steps: Double? {
        get { get_single(.kElementSteps) }
        set { set_single(.kElementSteps, to: newValue) }
    }
}

/// child tags within a `GPXSoundscapeExtensions` which has tag `gpxgd:TrackPointExtension`
enum GPXSoundscapeExtensionsProperties : String {
    case kElementHorizontalAccuracy = "gpxgd:hor_acc"
    case kElementVerticalAccuracy = "gpxgd:ver_acc"
    
    case kElementTrueHeading = "gpxgd:hdg_tru"
    case kElementMagneticHeading = "gpxgd:hdg_mag"
    case kElementHeadingAccuracy = "gpxgd:hdg_acc"
    case kElementDeviceHeading = "gpxgd:hdg_dvc"
    
    case kElementFloorLevel = "gpxgd:flr_lvl"
    
    case kElementMotionActivity = "gpxgd:activity"
}

extension GPXExtensionView<GPXSoundscapeExtensionsProperties> {
    public var horizontalAccuracy: Double? {
        get { get_single(.kElementHorizontalAccuracy) }
        set { set_single(.kElementHorizontalAccuracy, to: newValue) }
    }
    public var verticalAccuracy: Double? {
        get { get_single(.kElementVerticalAccuracy) }
        set { set_single(.kElementVerticalAccuracy, to: newValue) }
    }
    public var trueHeading: Double? {
        get { get_single(.kElementTrueHeading) }
        set { set_single(.kElementTrueHeading, to: newValue) }
    }
    public var magneticHeading: Double? {
        get { get_single(.kElementMagneticHeading) }
        set { set_single(.kElementMagneticHeading, to: newValue) }
    }
    public var headingAccuracy: Double? {
        get { get_single(.kElementHeadingAccuracy) }
        set { set_single(.kElementHeadingAccuracy, to: newValue) }
    }
    public var deviceHeading: Double? {
        get { get_single(.kElementDeviceHeading) }
        set { set_single(.kElementDeviceHeading, to: newValue) }
    }
    public var floorLevel: Double? {
        get { get_single(.kElementFloorLevel) }
        set { set_single(.kElementFloorLevel, to: newValue) }
    }
    public var motionActivity: String? {
        get { get_single(.kElementMotionActivity) }
        set { set_single(.kElementMotionActivity, to: newValue) }
    }
}

/// child tags within a `GPXSoundscapeSharedContentExtensions` which has tag `gpxsc:meta`
enum GPXSoundscapeSharedContentExtensionsProperties : String {
    // Experience Meta Tags
    case kElementID = "gpxsc:id" // 'required'
    case kElementBehavior = "gpxsc:behavior" // 'required'
    case kElementVersion = "gpxsc:version"
    // Experience Tags
    case kElementLocale = "gpxsc:locale" // 'required'
    // ??
    case kElementRegion = "gpxsc:region"
}
/// attribute keys within a `GPXSoundscapeSharedContentExtensions` which has tag `gpxsc:meta`
enum GPXSoundscapeSharedContentExtensionsAttributes : String {
    case kAttributeStartDate = "start"
    case kAttributeEndDate = "end"
    case kAttributeExpires = "expires"
}
class GPXSoundscapeRegion {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var radius: CLLocationDistance
    
    init?(element: GPXExtensionsElement) {
        guard element.name == GPXSoundscapeSharedContentExtensionsProperties.kElementRegion.rawValue,
              let lat = element.attributes["lat"],
              let lat = CLLocationDegrees(lat),
              let lon = element.attributes["lon"],
              let lon = CLLocationDegrees(lon),
              let rad = element.attributes["radius"],
              let rad = CLLocationDistance(rad) else {
            return nil
        }
        latitude = lat
        longitude = lon
        radius = rad
    }
    
    var region: CLCircularRegion {
        return CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: "SoundscapeExperienceRegion")
    }
}
extension GPXExtensionView<GPXSoundscapeSharedContentExtensionsProperties> {
    public var id: String? {
        get { get_single(.kElementID) }
        set { set_single(.kElementID, to: newValue) }
    }
    public var behavior: String? {
        get { get_single(.kElementBehavior) }
        set { set_single(.kElementBehavior, to: newValue) }
    }
    public var version: String? {
        get { get_single(.kElementVersion) }
        set { set_single(.kElementVersion, to: newValue) }
    }
    /// Seems to be unused.
    public var region: GPXSoundscapeRegion? {
        get {
            guard let element = ref?.children.first(where: {$0.name == E.kElementRegion.rawValue}) else {
                return nil
            }
            return GPXSoundscapeRegion(element: element)
        }
        // TODO: make a setter
    }
    /// If set to an invalid or unknown value, will not catch that and will save/read back that locale identifier
    public var locale: Locale? {
        get {
            guard let locale_id = get_single(.kElementLocale) else {
                return nil
            }
            return Locale(identifier: locale_id)
        }
        set { set_single(.kElementLocale, to: newValue?.identifier) }
    }
    /// This is the correct date formatter for the GPX format
    private static let dateFormatter = ISO8601DateFormatter()
    /// If `nil`, then start date is in the distant past
    public var startDate: Date? {
        get {
            guard let startStr = ref?.attributes[GPXSoundscapeSharedContentExtensionsAttributes.kAttributeStartDate.rawValue],
                  let start = GPXExtensionView<GPXSoundscapeSharedContentExtensionsProperties>.dateFormatter.date(from: startStr) else {
                return nil
            }
            return start
        }
        set {
            var value: String? = nil
            if let newValue = newValue, newValue != Date.distantPast {
                value = GPXExtensionView<GPXSoundscapeSharedContentExtensionsProperties>.dateFormatter.string(from: newValue)
            }
            ref?.attributes[GPXSoundscapeSharedContentExtensionsAttributes.kAttributeStartDate.rawValue] = value
        }
    }
    /// If `nil`, then end date is in the distant future
    public var endDate: Date? {
        get {
            guard let endStr = ref?.attributes[GPXSoundscapeSharedContentExtensionsAttributes.kAttributeEndDate.rawValue],
                  let end = GPXExtensionView<GPXSoundscapeSharedContentExtensionsProperties>.dateFormatter.date(from: endStr) else {
                return nil
            }
            return end
        }
        set {
            var value: String? = nil
            if let newValue = newValue, newValue != Date.distantFuture {
                value = GPXExtensionView<GPXSoundscapeSharedContentExtensionsProperties>.dateFormatter.string(from: newValue)
            }
            ref?.attributes[GPXSoundscapeSharedContentExtensionsAttributes.kAttributeEndDate.rawValue] = value
        }
    }
    /// If not present, it does not expire (i.e. false)
    public var expires: Bool {
        get { ref?.attributes[GPXSoundscapeSharedContentExtensionsAttributes.kAttributeExpires.rawValue] == "true" }
        set { ref?.attributes[GPXSoundscapeSharedContentExtensionsAttributes.kAttributeExpires.rawValue] = (newValue ? "true" : "false") }
    }
    /// Based on the Soundscape patch for the old Objective-C version of iOS-GPX-Framework
    ///
    /// Uses the `startDate` and `endDate` properties
    public var availability: DateInterval {
        get {
            let start = startDate ?? Date.distantPast
            let end = endDate ?? Date.distantFuture
            return DateInterval(start: start, end: end)
        }
        set {
            startDate = (newValue.start == Date.distantPast) ? nil : newValue.start
            endDate = (newValue.end == Date.distantFuture) ? nil : newValue.end
        }
    }
}

/// child tags within a `GPXSoundscapeAnnotationExtensions` which has tag `gpxsc:annotations`
enum GPXSoundscapeAnnotationExtensionsProperties : String {
    case kAnnotation = "gpxsc:annotation"
}
/// attribute keys within a `GPXSoundscapeAnnotation` - note this is the single annotation tag, not the extension.
enum GPXSoundscapeAnnotationAttributes : String {
    case kAttributeTitle = "title"
    case kAttributeType = "type"
}

/// ```xml
/// From the following GPX tags:
/// <gpxsc:annotations>
///     <gpxsc:annotation type="TYPE HERE" title="TITLE HERE">CONTENT HERE</gpxsc:annotation> [0..N]
/// </gpxsc:annotations>
/// ```
class GPXAnnotation {
    // TODO: make this work better with the GPX system
    var title: String?
    /// Obj-C patch makes this non-null
    var content: String
    var type: String?
    
    init(element: GPXExtensionsElement) {
        content = element.text ?? ""
        title = element.attributes[GPXSoundscapeAnnotationAttributes.kAttributeTitle.rawValue]
        type = element.attributes[GPXSoundscapeAnnotationAttributes.kAttributeType.rawValue]
    }
}
extension GPXExtensionView<GPXSoundscapeAnnotationExtensionsProperties> {
    public var annotations: [GPXAnnotation] {
        get {
            return ref?.children.filter({$0.name == E.kAnnotation.rawValue}).compactMap( GPXAnnotation.init ) ?? []
        }
        // TODO: a setter maybe?
    }
    
    /// Parses and returns the first `gpxsc:annotation` child found with the specified annotation type
    public func getFirstAnnotation(withType type: String) -> GPXAnnotation? {
        guard let element = ref?.children.first(where: {$0.name == E.kAnnotation.rawValue && $0.attributes[GPXSoundscapeAnnotationAttributes.kAttributeType.rawValue] == type }) else {
            return nil
        }
        return GPXAnnotation(element: element)
    }
}

/// child tags within a `GPXSoundscapeAnnotationExtensions` which has tag `gpxsc:annotations`
enum GPXSoundscapeLinkExtensionsProperties : String {
    case kLink = "gpxsc:link"
}
extension GPXExtensionView<GPXSoundscapeLinkExtensionsProperties> {
    public var links: [GPXLink] {
        get {
            // We store stuff as GPXSoundscapeLink which is an empty subclass of GPXLink
            return ref?.children.filter({$0.name == E.kLink.rawValue}).compactMap({
                let link = GPXLink()
                link.mimetype = $0.get_property("type")
                link.text = $0.get_property("text")
                link.href = $0.attributes["href"]
                return link
            }) ?? []
        }
        // TODO: a setter maybe?
    }
}

/// child tags within a `GPXSoundscapePOIExtensions` which has tag `gpxsc:poi`
enum GPXSoundscapePOIExtensionsProperties : String {
    case kElementStreetAddress = "gpxsc:street"
    case kElementPhone = "gpxsc:phone"
    case kElementHomepage = "link" // I think this is a normal link, and lacks a "gpxsc:"
}
extension GPXExtensionView<GPXSoundscapePOIExtensionsProperties> {
    public var street: String? {
        get { get_single(.kElementStreetAddress) }
        set { set_single(.kElementStreetAddress, to: newValue) }
    }
    public var phone: String? {
        get { get_single(.kElementPhone) }
        set { set_single(.kElementPhone, to: newValue) }
    }
    public var homepage: GPXLink? {
        get {
            guard let element = ref?.children.first(where: { $0.name == E.kElementHomepage.rawValue }) else {
                return nil
            }
            let link = GPXLink()
            link.mimetype = element.get_property("type")
            link.text = element.get_property("name")
            link.href = element.attributes["href"]
            return link
        }
        set {
            // if set to nil, remove all links
            guard let newValue = newValue else {
                ref?.children.removeAll(where: { $0.name == E.kElementHomepage.rawValue })
                return
            }
            guard let element = ref?.children.first(where: { $0.name == E.kElementHomepage.rawValue }) else{
                // If there is no existing link element, create a new one
                let element = GPXExtensionsElement(name: E.kElementHomepage.rawValue)
                element.attributes["href"] = newValue.href
                element.set_property("type", to: newValue.mimetype)
                element.set_property("name", to: newValue.text)
                ref?.children.append(element)
                return
            }
            // otherwise there is an existing one: overwrite it
            element.attributes["href"] = newValue.href
            element.set_property("type", to: newValue.mimetype)
            element.set_property("name", to: newValue.text)
        }
    }
}

/// CoreGPX seems to prefer to leave things just as `GPXExtensionsElement`s so we'll just use that
/// But, for ease of use add ``GPXExtensionView`` to allow easy lookup of named tags
extension GPXExtensions {
    /// A getter specifically for our extensions
    private func get_ext(_ name: GPXExtensionsKeys) -> GPXExtensionsElement? {
        return children.first { $0.name == name.rawValue }
    }
    
    /// Formerly type `GPXTrackPointExtensions`
    var garminExtensions: GPXExtensionView<GPXTrackPointExtensionsProperties>? {
        guard let ext = get_ext(.kGPXTrackPointExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXTrailsTrackExtensions`
    var trailsTrackExtensions: GPXExtensionView<GPXTrailsTrackExtensionsProperties>? {
        guard let ext = get_ext(.kGPXTrailsTrackExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXTrailsTrackPointExtensions`
    var trailsTrackPointExtensions: GPXExtensionView<GPXTrailsTrackPointExtensionsProperties>? {
        guard let ext = get_ext(.kGPXTrailsTrackPointExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXSoundscapeExtensions`
    var soundscapeExtensions: GPXExtensionView<GPXSoundscapeExtensionsProperties>? {
        guard let ext = get_ext(.kGPXSoundscapeExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXSoundscapeSharedContentExtensions`
    /// see: ``GPXSoundscapeSharedContentExtensionsAttributes``
    var soundscapeSCExtensions: GPXExtensionView<GPXSoundscapeSharedContentExtensionsProperties>? {
        guard let ext = get_ext(.kGPXSoundscapeSharedContentExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXSoundscapeAnnotationExtensions`
    /// Should contain `GPXSoundscapeAnnotation`s: see ``GPXSoundscapeAnnotationAttributes``
    var soundscapeAnnotationExtensions: GPXExtensionView<GPXSoundscapeAnnotationExtensionsProperties>? {
        guard let ext = get_ext(.kGPXSoundscapeAnnotationExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXSoundscapeLinkExtensions`
    /// Should contain `GPXSoundscapeLink` with tag `gpxsc:link`
    var soundscapeLinkExtensions: GPXExtensionView<GPXSoundscapeLinkExtensionsProperties>? {
        guard let ext = get_ext(.kGPXSoundscapeLinkExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
    
    /// Formerly type `GPXSoundscapePOIExtensions`
    var soundscapePOIExtensions: GPXExtensionView<GPXSoundscapePOIExtensionsProperties>? {
        guard let ext = get_ext(.kGPXSoundscapePOIExtensions) else {
            return nil
        }
        return GPXExtensionView(ext)
    }
}

// MARK: End Implementing Custom GPX Extensions

extension GPXWaypoint {

    /// This can be used to check if a timestamp of a `CLLocation` created with a waypoint is compared to nil.
    /// Date is `Date(timeIntervalSince1970: 0)`.
    class func noDateIdentifier() -> Date {
        return Date(timeIntervalSince1970: 0)
    }
    
    var hasSoundscapeExtension: Bool {
        return extensions?.soundscapeExtensions != nil
    }
    
    convenience init(with gpxLocation: GPXLocation) {
        self.init()
        
        let location = gpxLocation.location
        
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        elevation = location.altitude
        time = location.timestamp
        
        let extensions = GPXExtensions()
        
        extensions.children.append(BuildGPXExtension(.kGPXTrackPointExtensions))
        let garminExtension = extensions.garminExtensions!
        garminExtension.speed = location.speed
        garminExtension.course = location.course
        
        extensions.children.append(BuildGPXExtension(.kGPXSoundscapeExtensions))
        let soundscapeExtension = extensions.soundscapeExtensions!
        soundscapeExtension.horizontalAccuracy = location.horizontalAccuracy
        soundscapeExtension.verticalAccuracy = location.verticalAccuracy
        
        if let heading = gpxLocation.deviceHeading {
            soundscapeExtension.deviceHeading =  heading
        }
        if let activity = gpxLocation.activity, activity != ActivityType.unknown.rawValue {
            soundscapeExtension.motionActivity = activity
        }
        
        self.extensions = extensions
    }

    /// Note: if a waypoint's timestamp is nil (when the GPX file does not contain time values),
    /// we use `noDateIdentifier` to symbolize nil, because `CLLocation` cannot contain nil timestamps.
    func gpxLocation() -> GPXLocation {
        var speed: CLLocationSpeed = -1
        var course: CLLocationDirection = -1
        
        var horizontalAccuracy: CLLocationAccuracy = -1
        var verticalAccuracy: CLLocationAccuracy = -1

        var trueHeading: CLLocationDirection = -1
        var magneticHeading: CLLocationDirection = -1
        var headingAccuracy: CLLocationDirection = -1
        
        var deviceHeading: Double?

        var activity: GPXActivity?

        // Backwards compatibility: previously openscape used the dilution values for accuracy
        horizontalAccuracy = horizontalDilution ?? horizontalAccuracy
        verticalAccuracy = verticalDilution ?? verticalAccuracy

        if let extensions = extensions {
            // Backwards compatibility: previously openscape used to store speed and course directly in the extensions class
            if let speedText = extensions.children.first(where: { $0.name == "speed" })?.text,
               let speedNum = CLLocationSpeed(speedText) {
                speed = speedNum
            }
            if let courseText = extensions.children.first(where: { $0.name == "course" })?.text,
               let courseNum = CLLocationDirection(courseText) {
                course = courseNum
            }
            
            if let garminExtensions = extensions.garminExtensions {
                if let garminSpeed = garminExtensions.speed,
                   let speedNum = CLLocationSpeed(exactly: garminSpeed) {
                    speed = speedNum
                }
                
                if let garminCourse = garminExtensions.course,
                   let courseNum = CLLocationDirection(exactly: garminCourse) {
                    course = courseNum
                }
            }
            
            if let soundscapeExtensions = extensions.soundscapeExtensions {
                if let hAcc = soundscapeExtensions.horizontalAccuracy,
                   let hAccNum = CLLocationAccuracy(exactly: hAcc) {
                    horizontalAccuracy = hAccNum
                }
                
                if let vAcc = soundscapeExtensions.verticalAccuracy,
                   let vAccNum = CLLocationAccuracy(exactly: vAcc) {
                    verticalAccuracy = vAccNum
                }
                
                if let sTrueHeading = soundscapeExtensions.trueHeading,
                   let sTrueHeadingNum = CLLocationDirection(exactly: sTrueHeading) {
                    trueHeading = sTrueHeadingNum
                }
                
                if let sMagneticHeading = soundscapeExtensions.magneticHeading,
                   let sMagneticHeadingNum = CLLocationDirection(exactly: sMagneticHeading) {
                    magneticHeading = sMagneticHeadingNum
                }
                
                if let sHeadingAccuracy = soundscapeExtensions.headingAccuracy,
                   let sHeadingAccuracyNum = CLLocationDirection(exactly: sHeadingAccuracy) {
                    headingAccuracy = sHeadingAccuracyNum
                }
                
                if let sDeviceHeading = soundscapeExtensions.deviceHeading,
                   let sDeviceHeadingNum = CLLocationDirection(exactly: sDeviceHeading) {
                    deviceHeading = sDeviceHeadingNum
                }
                
                // Previous versions of the GPX tracker
                // and simulator used `trueHeading` and `magneticHeading`
                // rather than `deviceHeading`
                // If necessary, translate `trueHeading` and `magneticHeading`
                // to `deviceHeading`
                if deviceHeading == nil {
                    if trueHeading >= 0.0 {
                        // Use `trueHeading` if it is valid
                        // `trueHeading` is valid if its value is >= 0.0
                        deviceHeading = trueHeading
                    } else if headingAccuracy >= 0.0 {
                        // Use `magneticHeading` if it is valid
                        // `magneticHeading` is valid if `headingAccuracy` is >= 0.0
                        deviceHeading = magneticHeading
                    }
                }
                
                activity = soundscapeExtensions.motionActivity
            }
        }
        
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!),
                                  altitude: elevation ?? 0, // default value???
                                  horizontalAccuracy: horizontalAccuracy,
                                  verticalAccuracy: verticalAccuracy,
                                  course: course,
                                  speed: speed,
                                  timestamp: time ?? GPXWaypoint.noDateIdentifier())
        
        return GPXLocation(location: location, deviceHeading: deviceHeading, activity: activity)
    }
    
}

extension Array where Element == CLLocationCoordinate2D {
    func toGPXRoute() -> GPXRoute {
        let routePoints = self.compactMap { GPXRoutePoint(latitude: $0.latitude, longitude: $0.longitude) }
        let route = GPXRoute()
        route.points = routePoints
        
        return route
    }
}
