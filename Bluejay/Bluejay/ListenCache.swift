//
//  ListenCache.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-04-28.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// The `ListenCache` is used to store the service and characteristic UUID of a listen that needs to be restored in the event of a state restoration. It can also serialize and deserialize the model into and back from Data, so that it can be stored and retrieved from UserDefaults.
struct ListenCache {
    
    let serviceUUID: String
    let characteristicUUID: String
    
    class Coding: NSObject, NSCoding {
        
        let entry: ListenCache?
        
        init(entry: ListenCache) {
            self.entry = entry
            super.init()
        }
        
        required init?(coder aDecoder: NSCoder) {
            guard
                let serviceUUID = aDecoder.decodeObject(forKey: "serviceUUID") as? String,
                let characteristicUUID = aDecoder.decodeObject(forKey: "characteristicUUID") as? String
            else {
                return nil
            }
            
            entry = ListenCache(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID)
            
            super.init()
        }
        
        public func encode(with aCoder: NSCoder) {
            guard let entry = entry else {
                return
            }
            
            aCoder.encode(entry.serviceUUID, forKey: "serviceUUID")
            aCoder.encode(entry.characteristicUUID, forKey: "characteristicUUID")
        }
        
    }
    
}

protocol Encodable {
    var encoded: Decodable? { get }
}
protocol Decodable {
    var decoded: Encodable? { get }
}

extension ListenCache: Encodable {
    var encoded: Decodable? {
        return ListenCache.Coding(entry: self)
    }
}

extension ListenCache.Coding: Decodable {
    var decoded: Encodable? {
        return self.entry
    }
}
