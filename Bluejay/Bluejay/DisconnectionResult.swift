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
    case success(CBPeripheral)
    case cancelled
    case failure(Swift.Error)
}
