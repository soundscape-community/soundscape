//
//  GeoJsonFeature.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum GeoJsonFeatureError: Error {
    /// Thrown when the json's `type` property is not `"Feature"`
    case incorrectTypeField
    /// When a feature does not have a name
    ///
    /// Optionally contains a string containing its `feature_type` and `feature_value`: `<type>=<value>`.
    ///
    /// While the [GeoJson spec](https://datatracker.ietf.org/doc/html/rfc7946#section-3.2) does not require a name, we are unable to handle features we can't find a name for (Note: I'm not sure why, so I may just be replicating a historical bug).
    case nameless(propVal: String?)
}

final class GeoJsonFeature: Decodable {
    enum CodingKeys: String, CodingKey {
        /// Key for accessing the `feature_type` property of a GeoJson feature
        case feature_type
        /// Key for accessing the `feature_value` property of a GeoJson feature
        case feature_value
        /// Key for accessing the `geometry` (``GeoJsonGeometry``) object of a GeoJson feature
        case geometry
        /// Key for accessing the OSM IDs array of a GeoJson feature
        case osm_ids
        /// Key for accessing the `priority` integer of a GeoJson feature
        case priority
        /// Key for accessing the `properties` dictionary of a GeoJson feature
        case properties
        /// Key for accessing the `name` property from the properties dictionary of a GeoJson feature
        case name
        /// Key for accessing the `ref` property from the properties dictionary of a GeoJson feature
        case ref
        /// Prefix string which all localized names have in the properties dictionary of a GeoJson feature
        case i18nNamePrefix = "name:"
        /// Key for the json `type`, should always be `"Feature"`
        case type
    }
    // MARK: Properties
    
    /// Name of the feature
    var name: String?
    
    /// Localized variations of the feature's name.
    /// - example: `["en": "Louvre Museum", "fr": "Musée du Louvre"]`
    var names: [String: String]?
    
    /// Name tag, e.g. "walking_path".
    /// - note: Should be on of the values in `supportedOSMTags`.
    var nameTag: String?
    
    /// "ref" stands for "reference" and is used for reference numbers or codes.
    /// Common for roads, highway exits, routes, etc. It is also used for shops and amenities
    /// that are numbered officially as part of a retail brand or network respectively.
    /// - link: https://wiki.openstreetmap.org/wiki/Key:ref
    var ref: String?
    
    /// OSM IDs for all ways, nodes, and relations involved in this feature
    var osmIds: [String] = []
    
    /// High level type of this feature (e.g. "highway")
    var type: String
    
    /// Value of the high level type of this feature (e.g. "footpath")
    var value: String
    
    /// Bag of all properties from OSM for this feature
    var properties: [String: String] = [:]
    
    /// Priority of the feature
    var priority: UInt = 0
    
    /// Name of the super category this feature belongs to
    var superCategory: SuperCategory = .undefined
    
    /// Geometry of this feature
    /// While Features are required to have a `geometry` member, it may be `null` for unlocated features, represented here as `nil`
    var geometry: GeoJsonGeometry?
    
    var isCrossing = false
    
    var isRoundabout = false
    
    // MARK: Initializers
    
    /// ``JSONDecoder``
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Object's `type` property must be "Feature"
        let parsed_type = try container.decode(String.self, forKey: .type)
        guard parsed_type == "Feature" else {
            throw GeoJsonFeatureError.incorrectTypeField
        }
        
        // Parse OSM IDs
        let parsed_ids = try? container.decode([Int].self, forKey: .osm_ids)
        osmIds = parsed_ids?.map({ "ft\($0)" }) ?? []
        
        // Parse the general feature information
        let parsed_feature_type = try? container.decode(String.self, forKey: .feature_type)
        type = parsed_feature_type ?? ""
        let parsed_feature_value = try? container.decode(String.self, forKey: .feature_value)
        value = parsed_feature_value ?? ""
        
        let nameObjects = GeoJsonFeature.extractNames(from: container)
        // Entities should have a name or a tag (which will be transformed to a localized name at runtime)
        guard nameObjects.name != nil || nameObjects.tag != nil else {
            // Collect information about this nameless feature for later analysis
            let propVal = type + "=" + value
            
            if !GeoJsonFeature.unhandledNamelessFeatures.contains(propVal) {
                GeoJsonFeature.unhandledNamelessFeatures.insert(propVal)
            }
            
            throw GeoJsonFeatureError.nameless(propVal: propVal)
        }
        
        name = nameObjects.name
        names = nameObjects.names
        nameTag = nameObjects.tag
        
        // note: `properties` isn't required by spec to be [String: String], but appears to always be in data from OSM
        if let featureProperties = try? container.decode([String: String].self, forKey: .properties) {
            self.properties = featureProperties
            
            if let ref = properties[CodingKeys.ref.rawValue] {
                self.ref = ref
            }
        }
        if GeoJsonFeature.hasTag("footway=crossing", props: properties) ||
            nameObjects.tag == GeoJsonFeature.FeatureNameTag.crossing {
            isCrossing = true
        }
        
        if let junction = properties["junction"], junction == "roundabout" || junction == "circular" {
            isRoundabout = true
        }
        
        // TODO: it is unclear if geometry not existing should cause the feature to be rejected
        geometry = try? container.decode(GeoJsonGeometry.self, forKey: .geometry)
        
        // Fix geometries for crossings with LineString geometries
        if isCrossing, case .lineString = geometry,
           let median = geometry?.getLineMedian() {
            geometry = GeoJsonGeometry(point: median)
        }
        
        // Parse the priority of the feature
        let parsedPriority = try? container.decode(UInt.self, forKey: .priority)
        priority = parsedPriority ?? 0
        
        //
        // Deal with super categories and missing names:
        //
        
        if GeoJsonFeature.hasTag("indoormark=beacon", props: properties) {
            superCategory = SuperCategory.beacons
            
            // TODO: What if the beacon wasn't named?
            
            return
        }
        
        // Case: crossings
        if isCrossing {
            superCategory = SuperCategory.mobility
            return
        }
        
        // Case: building entrance (entrances have a tag entrance=* by definition)
        if GeoJsonFeature.hasTag("entrance=*", props: properties) {
            // Note that features with the tag entrance=* either have a name or have already been given a name by the supported list
            superCategory = SuperCategory.entrances
            return
        }
        
        // Case: intersections (calculated intersections have value "gd_intersection" by definition)
        if value == "gd_intersection" {
            superCategory = SuperCategory.intersections
            return
        }
        
        // Case: entrance list (calculated entrance lists have type "gd_entrance_list" by definition)
        if type == "gd_entrance_list" {
            superCategory = SuperCategory.entranceLists
            return
        }
        
        // Case: bus stops
        if value == "bus_stop" {
            superCategory = SuperCategory.mobility
            return
        }
        
        // Case: ATMs
        if value == "atm" {
            superCategory = SuperCategory.mobility
            return
        }
        
        // Case: Banks
        if value == "bank" {
            superCategory = SuperCategory.places
            return
        }
        
        // Case: roads and footpaths
        if type == "highway" {
            if GeoJsonFeature.roadTags.contains(value) {
                superCategory = SuperCategory.roads
                return
            } else if GeoJsonFeature.pathTags.contains(value) {
                superCategory = SuperCategory.paths
                return
            }
        }
        
#if false
        // TODO: this is currently unused (we never passed in any supercategories, even before refactoring), but should probably be reviewed to determine if it should get implemented
        // General Case: look up the category in the list of categories we got from the server
        var applicableCategories: Set<SuperCategory> = []
        for (key, value) in properties {
            for (category, tags) in superCategories {
                if tags.contains(key) || tags.contains(value) {
                    applicableCategories.insert(category)
                }
            }
        }
        
        // There are multiple applicable categories, choose the highest priority one
        if let prioritizedCategory = GeoJsonFeature.prioritizedCategories.first(where: { applicableCategories.contains($0) }) {
            superCategory = prioritizedCategory
        }
#endif
    }
    
    init(copyFrom: GeoJsonFeature) {
        self.name = copyFrom.name
        
        if let copyNames = copyFrom.names {
            self.names = [:]
            for (key, value) in copyNames {
                self.names![key] = value
            }
        }
        
        for osmId in copyFrom.osmIds {
            self.osmIds.append(osmId)
        }
        
        self.type = copyFrom.type
        self.value = copyFrom.value
        
        for (key, value) in copyFrom.properties {
            self.properties[key] = value
        }
        
        // enums are pass-by-value
        self.priority = copyFrom.priority
        self.superCategory = copyFrom.superCategory
        self.geometry = copyFrom.geometry
    }
    
    func decomposePathToStartAndEndCrossings() -> (start: GeoJsonFeature, end: GeoJsonFeature)? {
        let startCopy = GeoJsonFeature(copyFrom: self)
        let endCopy = GeoJsonFeature(copyFrom: self)
        
        guard let first = geometry?.first, let last = geometry?.last else {
            return nil
        }
        
        startCopy.geometry = .point(coordinates: first)
        startCopy.superCategory = SuperCategory.mobility

        endCopy.geometry = .point(coordinates: last)
        endCopy.superCategory = SuperCategory.mobility
            
        return (startCopy, endCopy)
    }
    
    /// Check if a set of properties contains a key-value pair matching the input tag. Tags are
    /// strings with the structure <key>=<value> where either/both of <key> and <value> can be
    /// wildcards.
    ///
    /// - Parameters:
    ///   - tag: Tag pattern to search for
    ///   - props: Property bag to search in
    /// - Returns: True if a property matching the given tag exists, false otherwise
    static func hasTag(_ tag: String, props: [String: String]) -> Bool {
        for (prop, val) in props {
            if tag == "*=*" || tag == "*=" + val || tag == prop + "=*" || tag == prop + "=" + val {
                return true
            }
        }
        
        return false
    }
    
    /// Checks the nameless POI supported list for a name for a given key:value pair
    ///
    /// - Parameters:
    ///   - key: Key value
    ///   - value: Tag value
    /// - Returns: POI name tag if the key:value pair is in the supported list, or nil otherwise
    static func supportedOSMTag(key: String, value: String) -> (tag: String, priority: Int?)? {
        // Check exact match
        if let match = supportedOSMTags[key + "=" + value] {
            return (match, supportedOSMTagPriorities[key])
        }
        
        // Check wildcards
        if let match = supportedOSMTags["*=" + value] {
            return (match, supportedOSMTagPriorities[value])
        }
        
        if let match = supportedOSMTags[key + "=*"] {
            return (match, supportedOSMTagPriorities[key])
        }
        
        // Tag is not in the supported list
        return nil
    }
    
}

// MARK: - Initialization Helpers

extension GeoJsonFeature {
    
    fileprivate static func extractIDs(from json: [String: Any]) -> [String]? {
        guard let ids = json[CodingKeys.osm_ids.rawValue] as? [Int] else { return nil }
        
        return ids.map({ (id) -> String in
            return "ft\(id)"
        })
    }
    
    fileprivate static func extractNames(from container: KeyedDecodingContainer<CodingKeys>) -> (name: String?, names: [String: String]?, tag: String?) {
        guard let properties = try? container.decode([String: String].self, forKey: .properties) else {
            return (nil, nil, nil)
        }
        
        if let value = try? container.decode(String.self, forKey: .feature_value),
           value == "gd_intersection" {
            // Special case: intersections (calculated intersections have value "gd_intersection" by definition)
            return (name: GDLocalizedString("osm.tag.intersection"), nil, "intersection")
        }
        
        if let type = try? container.decode(String.self, forKey: .feature_type),
           type == "gd_entrance_list"{
            // Special case: entrance list (calculated entrance lists have type "gd_entrance_list" by definition)
            return (name: GDLocalizedString("directions.amenity.entrance_list"), nil, nil)
        }

        var name: String?
        var names: [String: String]?

        // Try to extract name and i18n names
        for (property, value) in properties {
            if property == CodingKeys.name.rawValue {
                name = value
                continue
            }
            
            if let range = property.range(of: CodingKeys.i18nNamePrefix.rawValue) {
                var languageCode = property
                languageCode.removeSubrange(range)
                
                if names == nil {
                    names = [languageCode: value]
                } else {
                    names![languageCode] = value
                }
            }
        }
        
        // Custom name extractions
        if name == nil, let featureValue = try? container.decode(String.self, forKey: .feature_value) {
            if featureValue == "atm", let atm = properties["operator"], atm.count > 0 {
                name = atm
            } else if featureValue == "bank" {
                if let bank = properties["operator"], bank.count > 0 {
                    name = bank
                } else if let bank = properties["brand"], bank.count > 0 {
                    name = bank
                }
            }
        }
        
        let tag = GeoJsonFeature.extractSupportedTag(from: properties)

        return (name: name, names, tag)
    }
    
    static func extractSupportedTag(from properties: [String: String]) -> String? {
        guard properties.count > 0 else { return nil }
        
        var tag: String?
        var priority = Int.max
        
        for (property, value) in properties {
            guard let (currentTag, currentPriority) = GeoJsonFeature.supportedOSMTag(key: property, value: value) else { continue }
            
            if let currentPriority = currentPriority {
                if currentPriority < priority {
                    tag = currentTag
                    priority = currentPriority
                }
            } else if tag == nil {
                tag = currentTag
            }
        }
        
        return tag
    }
    
}

extension GeoJsonFeature {
    
    /// Set for tracking unhandled nameless features
    static var unhandledNamelessFeatures = Set<String>()
    
    /// Prioritized categories for handeling features with unknown categories
    static let prioritizedCategories = [SuperCategory.safety,
                                        SuperCategory.mobility,
                                        SuperCategory.landmarks,
                                        SuperCategory.places,
                                        SuperCategory.objects,
                                        SuperCategory.information]

    static let supportedOSMTagPriorities = [
        "entrance": 0,
        "emergency": 0,
        "amenity": 1,
        "crossing": 1,
        "shop": 1,
        "construction": 1,
        "barrier": 1,
        "leisure": 1,
        "tourism": 1,
        "building": 2,
        "highway": 2
    ]
    
    /// Supported OSM feature tags
    static let supportedOSMTags = [
        "crossing=*": "crossing",
        "*=crossing": "crossing",
        "*=construction": "construction",
        "construction=*": "construction",
        "*=danger_area": "dangerous_area",
        "*=townhall": "townhall",
        "highway=bus_stop": "bus_stop",
        "highway=steps": "steps",
        "highway=elevator": "elevator",
        "highway=footway": "walking_path",
        "highway=path": "walking_path",
        "highway=pedestrian": "pedestrian_street",
        "highway=cycleway": "bicycle_path",
        "highway=residential": "residential_street",
        "highway=service": "service_road",
        "highway=track": "road",
        "highway=unclassified": "road",
        "highway=tertiary": "road",
        "highway=tertiary_link": "road",
        "highway=secondary": "road",
        "highway=primary": "road",
        "highway=turning_circle": "roundabout",
        "highway=living_street": "road",
        "highway=trunk": "road",
        "highway=motorway": "highway",
        "highway=motorway_link": "highway_ramp",
        "highway=primary_link": "merging_lane",
        "building=office": "office_building",
        "building=school": "school_building",
        "building=roof": "covered_pavilion",
        "shop=convenience": "convenience_store",
        "entrance=*": "building_entrance",
        "emergency=assembly_point": "assembly_point",
        "barrier=cycle_barrier": "cycle_barrier",
        "barrier=turnstile": "turnstile",
        "barrier=cattle_grid": "cattle_grid",
        "barrier=gate": "gate",
        "barrier=lift_gate": "gate",
        "amenity=toilets": "restroom",
        "amenity=parking": "parking_lot",
        "amenity=parking_entrance": "parking_entrance",
        "amenity=bench": "bench",
        "amenity=taxi": "taxi_waiting_area",
        "amenity=post_office": "post_office",
        "amenity=post_box": "post_box",
        "amenity=waste_basket": "waste_basket",
        "amenity=shower": "shower",
        "amenity=bicycle_parking": "bike_parking",
        "amenity=cafe": "cafe",
        "amenity=restaurant": "restaurant",
        "amenity=telephone": "telephone",
        "amenity=fuel": "gas_station",
        "amenity=atm": "atm",
        "amenity=recycling": "recycling_bin",
        "amenity=fountain": "fountain",
        "amenity=place_of_worship": "place_of_worship",
        "amenity=drinking_water": "water_fountain",
        "amenity=car_wash": "car_wash",
        "amenity=vending_machine": "vending_machine",
        "leisure=playground": "playground",
        "leisure=pitch": "sports_field",
        "leisure=swimming_pool": "swimming_pool",
        "leisure=garden": "garden",
        "leisure=park": "park",
        "leisure=picnic_table": "picnic_table",
        "tourism=picnic_site": "picnic_area"
    ]
    
    /// Values that identify roads
    static let roadTags: Set = ["residential",
                                "service",
                                "track",
                                "unclassified",
                                "tertiary",
                                "secondary",
                                "primary",
                                "turning_circle",
                                "living_street",
                                "trunk",
                                "motorway",
                                "motorway_link",
                                "pedestrian"]
    
    /// Values that identify paths
    static let pathTags: Set = ["footway",
                                "path",
                                "cycleway",
                                "bridleway"]

    struct FeatureNameTag {
        static var crossing = "crossing"
    }
    
}
