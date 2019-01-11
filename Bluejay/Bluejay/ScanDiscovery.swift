//
//  ScanDiscovery.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-27.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/// A model capturing what is found from a scan callback.
public struct ScanDiscovery {
    /// The unique, persistent identifier associated with the peer.
    public let peripheralIdentifier: PeripheralIdentifier

    /// The advertisement packet the discovered peripheral is sending.
    public let advertisementPacket: [String: Any]

    /// The signal strength of the peripheral discovered.
    public let rssi: Int
}
