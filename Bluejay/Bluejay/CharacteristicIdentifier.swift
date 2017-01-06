//
//  CharacteristicIdentifier.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A wrapper for CBUUID specific to a characteristic to help distinguish it from a CBUUID of a service.
public struct CharacteristicIdentifier: Hashable {
    
    public private(set) var service: ServiceIdentifier
    public private(set) var uuid: CBUUID
    
    public init(_ cbCharacteristic: CBCharacteristic) {
        self.service = ServiceIdentifier(cbCharacteristic.service.uuid)
        self.uuid = cbCharacteristic.uuid
    }
    
    public init(uuid: String, service: ServiceIdentifier) {
        self.service = service
        self.uuid = CBUUID(string: uuid)
    }
    
    public var hashValue: Int {
        return uuid.hashValue
    }
    
    /// Check equality between two CharacteristicIdentifiers.
    public static func ==(lhs: CharacteristicIdentifier, rhs: CharacteristicIdentifier) -> Bool {
        return (lhs.uuid == rhs.uuid) && (lhs.service.uuid == rhs.service.uuid)
    }
    
    /// Check equality between a CharacteristicIdentifier and a CBCharacterstic.
    public static func ==(lhs: CharacteristicIdentifier, rhs: CBCharacteristic) -> Bool {
        return (lhs.uuid == rhs.uuid) && (lhs.service.uuid == rhs.service.uuid)
    }
    
}
