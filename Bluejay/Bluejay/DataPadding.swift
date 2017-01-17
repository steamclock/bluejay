//
//  DataPadding.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Helper object to create padding in packets being constructed.
public struct DataPadding: Sendable {
    
    private var amount: Int
    
    public init(_ amount: Int) {
        self.amount = amount
    }
    
    public func toBluetoothData() -> Data {
        return Data(count: amount)
    }
    
}
