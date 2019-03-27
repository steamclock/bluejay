//
//  CBPeripheralState+ReturnString.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-11.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

extension CBPeripheralState {

    /// Returns the name of a `CBPeripheralState` as a string.
    public func string() -> String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .disconnecting: return "Disconnecting"
        @unknown default:
            return "Unknown"
        }
    }

}
