//
//  ConnectionResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful, cancelled, or failed connection attempt, where the success case contains the peripheral connected to.
public enum ConnectionResult {
    /// The connection is successful, and the peripheral connected is captured in the associated value.
    case success(PeripheralIdentifier)
    /// The connection has failed unexpectedly with an error.
    case failure(Error)
}
