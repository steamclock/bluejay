//
//  StartOptions.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-10-09.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/// Wrapper for CBCentralManager initialization configurations when starting a new Bluejay instance.
public struct StartOptions {
    /// Whether to show an iOS system alert when Bluetooth is turned off while the app is still running in the background.
    var enableBluetoothAlert: Bool
    /// Enable or disable state restoration.
    var backgroundRestore: BackgroundRestoreMode

    /**
     * Configurations for starting Bluejay.
     *
     * - Parameters:
     *    - enableBluetoothAlert: whether to show an iOS system alert when Bluetooth is turned off while the app is still running in the background.
     *    - backgroundRestore: enable or disable state restoration.
     */
    public init(enableBluetoothAlert: Bool, backgroundRestore: BackgroundRestoreMode) {
        self.enableBluetoothAlert = enableBluetoothAlert
        self.backgroundRestore = backgroundRestore
    }

    /// Convenience factory method to avoid having to use the public initializer.
    public static var `default`: StartOptions {
        return StartOptions(enableBluetoothAlert: false, backgroundRestore: .disable)
    }
}

/// Specifies whether to start a new Bluejay instance from scratch, or from an existing CoreBluetooth session.
public enum StartMode {
    /// Start Bluejay using a new CBCentralManager.
    case new(StartOptions)
    /// Start Bluejay using an existing CBCentralManager.
    case use(manager: CBCentralManager, peripheral: CBPeripheral?)
}
