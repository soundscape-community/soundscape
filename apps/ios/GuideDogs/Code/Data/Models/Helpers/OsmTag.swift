//
//  OsmTag.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

import RealmSwift

class OsmTag: Object {
    
    @Persisted(primaryKey: true) var key = ""
    
    @Persisted var name = ""
    
    @Persisted var value = ""
    
    convenience init(name: String, value: String) {
        self.init()
        
        self.name = name
        self.value = value
        
        self.key = name + "=" + value
    }
}
