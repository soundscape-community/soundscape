//
//  GeoJsonFeatureTest.swift
//  UnitTests
//
//  Created by Kai on 11/8/23.
//  Copyright © 2023 Soundscape community. All rights reserved.
//

import XCTest
import CoreLocation
@testable import Soundscape


/// Note: see ``GeoJsonGeometryTest`` if issues arise regarding parsing of the contained geometry objects.
final class GeoJsonFeatureTest: XCTestCase {
    
    func testParseRPI() throws {
        let rpi_json = """
{
    "feature_type": "amenity",
    "feature_value": "university",
    "geometry": {
        "coordinates": [[[[-73.686467, 42.730566], [-73.686149, 42.732009], [-73.685002, 42.731883], [-73.683726, 42.731804], [-73.683392, 42.733057], [-73.682639, 42.732884], [-73.682458, 42.732802], [-73.681911, 42.732191], [-73.681714, 42.732282], [-73.681278, 42.733728], [-73.680441, 42.733561], [-73.679727, 42.733414], [-73.679364, 42.733336], [-73.678998, 42.733282], [-73.676712, 42.732955], [-73.676761, 42.732781], [-73.677151, 42.732838], [-73.677193, 42.732696], [-73.677726, 42.732782], [-73.677815, 42.732456], [-73.677903, 42.732135], [-73.677477, 42.731928], [-73.677807, 42.730778], [-73.677417, 42.730723], [-73.677159, 42.730717], [-73.676006, 42.73056], [-73.676017, 42.730672], [-73.675961, 42.73074], [-73.675475, 42.731016], [-73.674638, 42.730496], [-73.674799, 42.730409], [-73.67493, 42.730482], [-73.675212, 42.730647], [-73.675679, 42.730222], [-73.675501, 42.73017], [-73.675254, 42.730054], [-73.675167, 42.729998], [-73.674907, 42.729795], [-73.674852, 42.729732], [-73.674624, 42.729523], [-73.674487, 42.729452], [-73.674105, 42.729369], [-73.673404, 42.729424], [-73.672718, 42.729196], [-73.673533, 42.726224], [-73.675969, 42.726626], [-73.67629, 42.726823], [-73.67672, 42.727068], [-73.677428, 42.727328], [-73.677975, 42.727462], [-73.678137, 42.7275], [-73.678159, 42.727322], [-73.678187, 42.727021], [-73.678192, 42.727006], [-73.678198, 42.726995], [-73.678212, 42.726982], [-73.678226, 42.726972], [-73.678244, 42.726962], [-73.678264, 42.726956], [-73.678291, 42.726951], [-73.678314, 42.726951], [-73.678494, 42.726986], [-73.678777, 42.727041], [-73.679187, 42.727121], [-73.684755, 42.728203], [-73.684343, 42.729734], [-73.684201, 42.730261], [-73.686467, 42.730566]]], [[[-73.673503, 42.731682], [-73.673442, 42.731937], [-73.672991, 42.731879], [-73.672954, 42.732025], [-73.671747, 42.731875], [-73.671779, 42.731583], [-73.671382, 42.731524], [-73.671119, 42.731615], [-73.671037, 42.731946], [-73.671653, 42.732027], [-73.671589, 42.732252], [-73.67158, 42.732275], [-73.671566, 42.732285], [-73.67155, 42.73229], [-73.671534, 42.73229], [-73.671493, 42.732285], [-73.671478, 42.732296], [-73.67098, 42.732248], [-73.670851, 42.732399], [-73.670733, 42.732616], [-73.670164, 42.733215], [-73.669569, 42.733928], [-73.669268, 42.734996], [-73.669022, 42.734964], [-73.668904, 42.735413], [-73.666012, 42.734937], [-73.665894, 42.735311], [-73.66553, 42.735268], [-73.665396, 42.735792], [-73.66517, 42.735756], [-73.66414, 42.73626], [-73.664017, 42.736438], [-73.664017, 42.736627], [-73.664237, 42.737001], [-73.663373, 42.737222], [-73.66296, 42.736477], [-73.663352, 42.735524], [-73.663143, 42.735437], [-73.662665, 42.735126], [-73.662923, 42.734176], [-73.66347, 42.733928], [-73.664596, 42.73301], [-73.665857, 42.732037], [-73.666731, 42.730965], [-73.666458, 42.730792], [-73.666377, 42.73048], [-73.666517, 42.72959], [-73.667557, 42.729795], [-73.667311, 42.730445], [-73.667187, 42.730792], [-73.667729, 42.730977], [-73.668035, 42.730497], [-73.668169, 42.730287], [-73.668244, 42.73009], [-73.668233, 42.729846], [-73.668056, 42.729546], [-73.668196, 42.729341], [-73.667917, 42.7292], [-73.668078, 42.72901], [-73.667649, 42.728758], [-73.667455, 42.728411], [-73.66826, 42.728289], [-73.669166, 42.729026], [-73.669011, 42.729144], [-73.66885, 42.729286], [-73.668775, 42.72946], [-73.668775, 42.729605], [-73.668877, 42.729862], [-73.669295, 42.730476], [-73.670583, 42.730449], [-73.672042, 42.730641], [-73.671792, 42.731521], [-73.672944, 42.731702], [-73.672965, 42.731612], [-73.673503, 42.731682]]], [[[-73.663248, 42.732892], [-73.663118, 42.733223], [-73.662257, 42.733463], [-73.661554, 42.735411], [-73.66107, 42.735223], [-73.660714, 42.734099], [-73.660986, 42.733317], [-73.661919, 42.732265], [-73.663121, 42.732549], [-73.663248, 42.732892]]], [[[-73.673902, 42.73513], [-73.673492, 42.736589], [-73.67202, 42.736366], [-73.67243, 42.734907], [-73.673902, 42.73513]]], [[[-73.670324, 42.736868], [-73.670168, 42.737384], [-73.668723, 42.737149], [-73.668801, 42.73689], [-73.668548, 42.736848], [-73.668626, 42.736591], [-73.670324, 42.736868]]]],
        "type": "MultiPolygon"
    },
    "osm_ids": [-100000000008670722],
    "properties": {
        "addr:city": "Troy",
        "addr:flats": "209;4213",
        "addr:housenumber": "110",
        "addr:postcode": "12180",
        "addr:state": "NY",
        "addr:street": "8th Street",
        "amenity": "university",
        "name": "Rensselaer Polytechnic Institute",
        "nysgissam:nysaddresspointid": "RENS081205;RENS045006;RENS080924",
        "smoking": "no",
        "type": "multipolygon",
        "website": "https://rpi.edu",
        "wikidata": "Q49211",
        "wikipedia": "en:Rensselaer Polytechnic Institute"
    },
    "type": "Feature"
}
""".data(using: .utf8)!
        
        let rpi_feature = try JSONDecoder().decode(GeoJsonFeature.self, from: rpi_json)
        // Since it's defined in a string, changes to OSM shouldn't affect this test
        
        XCTAssertEqual(rpi_feature.name, "Rensselaer Polytechnic Institute")
        XCTAssertEqual(rpi_feature.type, "amenity")
        XCTAssertEqual(rpi_feature.value, "university")
        XCTAssertEqual(rpi_feature.osmIds, ["ft-100000000008670722"])
        XCTAssertEqual(rpi_feature.geometry?.rawValue, "MultiPolygon")
        //XCTAssertEqual(rpi_feature.superCategory, .undefined)
        
        XCTAssertEqual(rpi_feature.properties, [
            "addr:city": "Troy",
            "addr:flats": "209;4213",
            "addr:housenumber": "110",
            "addr:postcode": "12180",
            "addr:state": "NY",
            "addr:street": "8th Street",
            "amenity": "university",
            "name": "Rensselaer Polytechnic Institute",
            "nysgissam:nysaddresspointid": "RENS081205;RENS045006;RENS080924",
            "smoking": "no",
            "type": "multipolygon",
            "website": "https://rpi.edu",
            "wikidata": "Q49211",
            "wikipedia": "en:Rensselaer Polytechnic Institute"
        ])
        
        // Is not a road
        XCTAssertFalse(rpi_feature.isCrossing) // that would make no sense
        XCTAssertFalse(rpi_feature.isRoundabout) // this too
        XCTAssertNil(rpi_feature.ref)
        XCTAssertNil(rpi_feature.nameTag)
    }
    
    func testParseSageAvenue() throws {
        let sage_json = """
{
    "feature_type": "highway",
    "feature_value": "tertiary",
    "geometry": {
        "coordinates": [[-73.677224, 42.730786], [-73.677061, 42.730764], [-73.676573, 42.730701], [-73.676491, 42.73068], [-73.676317, 42.730619], [-73.676147, 42.730521], [-73.675929, 42.730405]],
        "type": "LineString"
    },
    "osm_ids": [-669453514],
    "properties": {
        "highway": "tertiary",
        "maxspeed": "30 mph",
        "name": "Sage Avenue",
        "surface": "asphalt"
    },
    "type": "Feature"
}
""".data(using: .utf8)!
        
        let sage_feature = try JSONDecoder().decode(GeoJsonFeature.self, from: sage_json)
        // Since it's defined in a string, changes to OSM shouldn't affect this test
        
        XCTAssertEqual(sage_feature.name, "Sage Avenue")
        XCTAssertEqual(sage_feature.type, "highway")
        XCTAssertEqual(sage_feature.value, "tertiary")
        XCTAssertEqual(sage_feature.osmIds, ["ft-669453514"])
        XCTAssertEqual(sage_feature.geometry?.rawValue, "LineString")
        
        XCTAssertEqual(sage_feature.properties, [
            "highway": "tertiary",
            "maxspeed": "30 mph",
            "name": "Sage Avenue",
            "surface": "asphalt"
        ])
        
        // these are mostly determined by us, not a part of GeoJson spec
        XCTAssertEqual(sage_feature.superCategory, .roads)
        XCTAssertFalse(sage_feature.isCrossing)
        XCTAssertFalse(sage_feature.isRoundabout)
        XCTAssertNil(sage_feature.ref)
        XCTAssertEqual(sage_feature.nameTag, "road")
    }
    
    func testParseEmpty() throws {
        let data_empty_string = "".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(GeoJsonFeature.self, from: data_empty_string))
    }

}
