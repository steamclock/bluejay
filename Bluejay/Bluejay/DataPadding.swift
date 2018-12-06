//
//  DataPadding.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Helper object that can create empty data to be used as padding in packet construction.
public struct DataPadding: Sendable {

    /// The number of bytes to be used for padding.
    private var amount: Int

    /**
     Create empty data.
     
     - Parameter amount: number of bytes.
     */
    public init(_ amount: Int) {
        self.amount = amount
    }

    /// This function is required to conform to the `Sendable` protocol, which allows Bluejay to serialize `DataPadding` when performing write-related operations.
    public func toBluetoothData() -> Data {
        return Data(count: amount)
    }

}
