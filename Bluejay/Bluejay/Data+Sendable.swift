//
//  Data+Sendable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-03-09.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

extension Data: Sendable {

    /// Allows using Data as is when using Bluejay and working with write-related operations.
    public func toBluetoothData() -> Data {
        return self
    }

}

extension Data: Receivable {

    /// Allows using Data as is when using Bluejay and working with read-related operations.
    public init(bluetoothData: Data) {
        self = bluetoothData
    }

}
