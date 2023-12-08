//
//  IntersectionRoadId.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import RealmSwift

/// This class is simply a String wrapper that allows us to have an array of strings
/// stored in Realm with the Intersection object
class IntersectionRoadId: Object {
    @Persisted(primaryKey: true) var id: String = ""
    
    convenience init(withId id: String) {
        self.init()
        
        self.id = id
    }
}
