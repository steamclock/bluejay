//
//  PeripheralIdentifier.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Uniquely identifies a peripheral to the current iOS device. The UUID changes and is different on different iOS devices.
public struct PeripheralIdentifier {

    /// The UUID of the peripheral.
    public let uuid: UUID

    /// The UUID string of the peripheral.
    public var string: String {
        return uuid.uuidString
    }

    /// Create a PeripheralIdentifier using a UUID.
    public init(uuid: UUID) {
        self.uuid = uuid
    }
}

extension PeripheralIdentifier: Equatable {
    public static func == (lhs: PeripheralIdentifier, rhs: PeripheralIdentifier) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

extension PeripheralIdentifier: Hashable {
    public var hashValue: Int {
        return uuid.hashValue
    }
}
