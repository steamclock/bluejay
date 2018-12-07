//
//  Integer+Transferable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Extension to Int to make it Sendable and Receivable.
extension BinaryInteger {

    /// This function is required to conform to `Sendable`, and figures out the size of the `Integer` used by the iOS device.
    public func toBluetoothData() -> Data {
        var tmp = self
        return withUnsafePointer(to: &tmp) {
            Data(bytes: $0, count: MemoryLayout<Self>.size)
        }
    }

    /// This function is required to conform to `Receivable`, and figures out the size of the `Integer` used by the iOS device.
    public init(bluetoothData: Data) {
        var tmp: Self = 0
        (bluetoothData as NSData).getBytes(&tmp, length: MemoryLayout<Self>.size)
        self = tmp
    }

}

/// Extensions to existing primitive types to make them Sendable and Receivable.
extension Int64: Sendable, Receivable {}
extension Int32: Sendable, Receivable {}
extension Int16: Sendable, Receivable {}
extension Int8: Sendable, Receivable {}

extension UInt64: Sendable, Receivable {}
extension UInt32: Sendable, Receivable {}
extension UInt16: Sendable, Receivable {}
extension UInt8: Sendable, Receivable {}
