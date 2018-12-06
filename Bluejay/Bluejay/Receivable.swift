//
//  Receivable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Protocol to indicate that a type can be received from the Bluetooth connection.
public protocol Receivable {

    /**
     A place to implement your deserialization logic.
     
     - Parameter bluetoothData: The data received over Bluetooth and needing to be deserialized.
    */
    init(bluetoothData: Data) throws

}
