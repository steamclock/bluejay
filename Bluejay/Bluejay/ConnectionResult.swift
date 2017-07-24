//
//  ConnectionResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Indicates a successful, cancelled, or failed connection attempt, where the success case contains the peripheral connected to.
public enum ConnectionResult {
    case success(CBPeripheral)
    case cancelled
    case failure(Swift.Error)
}
