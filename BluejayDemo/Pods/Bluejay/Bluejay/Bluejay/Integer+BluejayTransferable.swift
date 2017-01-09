//
//  Integer+BluejayTransferable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Extensions to existing primitive types to make them BluejaySendable and BluejayReceivable.
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

extension Int64: BluejaySendable, BluejayReceivable {}
extension Int32: BluejaySendable, BluejayReceivable {}
extension Int16: BluejaySendable, BluejayReceivable {}
extension Int8: BluejaySendable, BluejayReceivable {}

extension UInt64: BluejaySendable, BluejayReceivable {}
extension UInt32: BluejaySendable, BluejayReceivable {}
extension UInt16: BluejaySendable, BluejayReceivable {}
extension UInt8: BluejaySendable, BluejayReceivable {}
