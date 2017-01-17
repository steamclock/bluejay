//
//  ConnectionResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful or failed connection attempt, where the success case contains the peripheral connected.
public enum ConnectionResult {
    case success(Peripheral)
    case failure(Swift.Error)
}
