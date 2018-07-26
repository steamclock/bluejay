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
    /// Bluejay will not receieve state restoration callbacks from CoreBluetooth.
    case disable
    /**
     Bluejay will receive state restoration callbacks from CoreBluetooth.
     
     - Note: Please provide a unique restore identifier for CoreBluetooth. See [Apple documentation](https://developer.apple.com/reference/corebluetooth/cbcentralmanageroptionrestoreidentifierkey) for more details.
    */
    case enable(RestoreIdentifier)
    /**
     Bluejay will receive state restoration callbacks from CoreBluetooth **and** attempt to restore listens when necessary using the provided listen restorer.
     
     - Note: Please provide a unique restore identifier for CoreBluetooth. See [Apple documentation](https://developer.apple.com/reference/corebluetooth/cbcentralmanageroptionrestoreidentifierkey) for more details.
     */
    case enableWithListenRestorer(RestoreIdentifier, ListenRestorer)
}

/// An alias to make it clearer that the string should be some kind of identifier for restoration, and not just any arbitrary string.
public typealias RestoreIdentifier = String
