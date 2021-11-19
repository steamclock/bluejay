//
//  CharacteristicIdentifier.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/// A wrapper for CBUUID specific to a characteristic to help distinguish it from a CBUUID of a service.
public struct CharacteristicIdentifier {
    /// The service this characteristic belongs to.
    public let service: ServiceIdentifier

    /// The `CBUUID` of this characteristic.
    public let uuid: CBUUID

    /// Create a `CharacteristicIdentifier` using a `CBCharacterstic`. Creation will fail if the "service" property of the CBCharacteristic is nil.
    /// Note: It isn't documented in CoreBluetooth under what circumstances that property might be nil, but it seems like it should almost never happen.
    public init?(_ cbCharacteristic: CBCharacteristic) {
        let optionalService: CBService? = cbCharacteristic.service // became optional with iOS 15 SDK, do a little dance to make it always optional so code below should compile on Xcode 12 or 13

        guard let service = optionalService else {
            return nil
        }

        self.service = ServiceIdentifier(uuid: service.uuid)
        self.uuid = cbCharacteristic.uuid
    }

    /// Returns the essential description of a characteristic.
    public var description: String {
        return "Characteristic: \(uuid.uuidString), Service: \(service.uuid.uuidString)"
    }

    /**
     * Create a `CharacteristicIdentifier` using a string and a `ServiceIdentifier`. Please supply a valid 128-bit UUID, or a valid 16 or 32-bit commonly used UUID.
     *
     * - Warning: If the uuid string provided is invalid and cannot be converted to a `CBUUID`, then there will be a fatal error.
     */
    public init(uuid: String, service: ServiceIdentifier) {
        self.uuid = CBUUID(string: uuid)
        self.service = service
    }

    /// Create a `CharacteristicIdentifier` using a `CBUUID` and a `ServiceIdentifier`.
    public init(uuid: CBUUID, service: ServiceIdentifier) {
        self.uuid = uuid
        self.service = service
    }

    /// Check equality between a `CharacteristicIdentifier` and a `CBCharacterstic`.
    public static func == (lhs: CharacteristicIdentifier, rhs: CBCharacteristic) -> Bool {
        let optionalService: CBService? = rhs.service // became optional with iOS 15 SDK, do a little dance to make it always optional so code below should compile on Xcode 12 or 13
        return (lhs.uuid == rhs.uuid) && (lhs.service.uuid == optionalService?.uuid)
    }
}

extension CharacteristicIdentifier: Hashable {
    /// Check equality between two CharacteristicIdentifiers.
    public static func == (lhs: CharacteristicIdentifier, rhs: CharacteristicIdentifier) -> Bool {
        return (lhs.uuid == rhs.uuid) && (lhs.service.uuid == rhs.service.uuid)
    }
    /// The hash value of the `CBUUID`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
        hasher.combine(service.uuid)
    }
}
