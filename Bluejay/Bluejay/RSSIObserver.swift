//
//  RSSIObserver.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-03-10.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
 A protocol allowing conforming objects to monitor the RSSI changes of a connected peripheral.
*/
public protocol RSSIObserver: class {

    /// Called whenever a peripheral's RSSI value changes.
    func peripheral(_ peripheral: Peripheral, didReadRSSI RSSI: NSNumber, error: Error?)

}

/// Allows creating weak references to RSSIObserver objects, so that Bluejay does not keep strong references to observers and prevent them from being released in memory.
struct WeakRSSIObserver {
    weak var weakReference: RSSIObserver?
}
