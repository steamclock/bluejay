//
//  ScanDiscovery.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-27.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

public struct ScanDiscovery {
    public let peripheral: CBPeripheral
    public let advertisementPacket: [String: Any]
    public let rssi: Int
}
