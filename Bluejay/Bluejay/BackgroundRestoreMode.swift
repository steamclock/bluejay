//
//  BackgroundRestoreMode.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-06-01.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Determines how Bluejay should opt-in to CoreBluetooth state restoration.
public enum BackgroundRestoreMode {
    /// Bluejay will not start CoreBluetooth with state restoration.
    case disable
    /// Bluejay will start CoreBluetooth with state restoration.
    case enable(BackgroundRestoreConfig)
}
