//
//  Integer+Transferable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Extensions to existing primitive types to make them Sendable and Receivable.
extension Integer {
    
    public init(bluetoothData: Data) {
        var tmp : Self = 0
        (bluetoothData as NSData).getBytes(&tmp, length: MemoryLayout<Self>.size)
        self = tmp
    }
    
    public func toBluetoothData() -> Data {
        var tmp = self
        return withUnsafePointer(to: &tmp) {
            return Data(bytes: $0, count: MemoryLayout<Self>.size)
        }
    }
    
}

extension Int64: Sendable, Receivable {}
extension Int32: Sendable, Receivable {}
extension Int16: Sendable, Receivable {}
extension Int8: Sendable, Receivable {}

extension UInt64: Sendable, Receivable {}
extension UInt32: Sendable, Receivable {}
extension UInt16: Sendable, Receivable {}
extension UInt8: Sendable, Receivable {}
