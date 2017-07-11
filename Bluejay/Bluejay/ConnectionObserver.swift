//
//  ConnectionObserver.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
    A protocol allowing conforming objects registered to Bluejay to optionally respond to Bluetooth connection events.
 
    - Attention
    On initial subscription to Bluetooth events, `bluetoothAvailable(_ available: Bool)` will always be called immediately with whatever the current state is, and `connected(to peripheral: Peripheral)` will also be called immediately if a device is already connected.

    - Note
    Available callbacks:
    * `func bluetoothAvailable(_ available: Bool)`
    * `func connected(_ peripheral: BluejayPeripheral)`
    * `func disconnected()`
*/
public protocol ConnectionObserver: class {
    
    /**
        Called whenever Bluetooth availability changes, as well as when an object first subscribes to observing Bluetooth events.
    */
    func bluetoothAvailable(_ available: Bool)
    func connected(to peripheral: Peripheral)
    func disconnected(from peripheral: Peripheral)
}

/// Slightly less gross way to make the ConnectionObserver protocol's functions optional.
extension ConnectionObserver {
    public func bluetoothAvailable(_ available: Bool) {}
    public func connected(to peripheral: Peripheral) {}
    public func disconnected(from peripheral: Peripheral) {}
}

/// Allows creating weak references to ConnectionObserver objects, so that the Bluejay singleton does not prevent the deallocation of those objects.
struct WeakConnectionObserver {
    weak var weakReference: ConnectionObserver?
}
