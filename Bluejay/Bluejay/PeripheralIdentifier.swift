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

    /// The name of the peripheral.
    public let name: String

    /// Returns both the name and uuid of the peripheral.
    public var description: String {
        return "Peripheral: \(name), UUID: \(uuid)"
    }

    /// Create a PeripheralIdentifier using a UUID.
    public init(uuid: UUID, name: String?) {
        self.uuid = uuid
        self.name = name ?? "No Name"
    }
}

extension PeripheralIdentifier: Hashable {
    public static func == (lhs: PeripheralIdentifier, rhs: PeripheralIdentifier) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
