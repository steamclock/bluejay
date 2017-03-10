//
//  RSSIObserver.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-03-10.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol RSSIObserver: class {
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Swift.Error?)
}

extension RSSIObserver {
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Swift.Error?) {}
}

struct WeakRSSIObserver {
    weak var weakReference: RSSIObserver?
}
