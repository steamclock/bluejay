//
//  DisconnectionResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-30.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Indicates a successful, cancelled, or failed disconnection attempt, where the success case contains the peripheral disconnected from.
public enum DisconnectionResult {
    /// The disconnection is successful, and the disconnected peripheral is captured in the associated value.
    case success(CBPeripheral)
    /// The disconnection is cancelled for a reason.
    case cancelled
    /// The disconnection has failed unexpectedly with an error.
    case failure(Error)
}
