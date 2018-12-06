//
//  Sendable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Protocol to indicate that a type can be sent via the Bluetooth connection.
public protocol Sendable {

    /**
     A place to implement your serialization logic.     
     */
    func toBluetoothData() -> Data
}
