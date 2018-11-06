//
//  ServiceIdentifier.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A wrapper for `CBUUID` specific to a service to help distinguish it from a `CBUUID` of a characteristic.
public struct ServiceIdentifier {

    /// The `CBUUID` of this service.
    public private(set) var uuid: CBUUID

    /**
     * Create a `ServiceIdentifier` using a string. Please supply a valid 128-bit UUID, or a valid 16 or 32-bit commonly used UUID.
     *
     * - Warning: If the uuid string provided is invalid and cannot be converted to a `CBUUID`, then there will be a fatal error.
     */
    public init(uuid: String) {
        self.uuid = CBUUID(string: uuid)
    }

    /// Create a `ServiceIdentifier` using a `CBUUID`.
    public init(uuid: CBUUID) {
        self.uuid = uuid
    }
}

extension ServiceIdentifier: Equatable {

    /// Check equality between two ServiceIdentifier.
    public static func == (lhs: ServiceIdentifier, rhs: ServiceIdentifier) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

extension ServiceIdentifier: Hashable {

    /// The hash value of the `CBUUID`.
    public var hashValue: Int {
        return uuid.hashValue
    }
}
