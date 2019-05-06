//
//  CBManagerState+ReturnString.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-11.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

@available(iOS 10.0, *)
extension CBManagerState {

    /// Returns the name of a `CBManagerState` as a string.
    public func string() -> String {
        switch self {
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unknown: return "Unknown"
        case .unsupported: return "Unsupported"
        @unknown default:
            return "Unknown"
        }
    }

}
