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
    On initial subscription to Bluetooth events, `bluetoothAvailable(_ available: Bool)` will always be called immediately with whatever the current state is, and `connected(to peripheral: PeripheralIdentifier)` will also be called immediately if a device is already connected.

    - Note
    Available callbacks:
    * `func bluetoothAvailable(_ available: Bool)`
    * `func connected(to peripheral: PeripheralIdentifier)`
    * `func disconnected(from peripheral: PeripheralIdentifier)`
*/
public protocol ConnectionObserver: class {

    /// Called whenever Bluetooth availability changes, as well as when an object first subscribes to become a ConnectionObserver.
    func bluetoothAvailable(_ available: Bool)

    /// Called whenever a peripheral is connected, as well as when an object first subscribes to become a ConnectionObserver and the peripheral is already connected.
    func connected(to peripheral: PeripheralIdentifier)

    /// Called whenever a peripheral is disconnected.
    func disconnected(from peripheral: PeripheralIdentifier)
}

/// Slightly less gross way to make the ConnectionObserver protocol's functions optional.
extension ConnectionObserver {
    public func bluetoothAvailable(_ available: Bool) {}
    public func connected(to peripheral: PeripheralIdentifier) {}
    public func disconnected(from peripheral: PeripheralIdentifier) {}
}

/// Allows creating weak references to ConnectionObserver objects, so that Bluejay does not keep strong references to observers and prevent them from being released in memory.
struct WeakConnectionObserver {
    weak var weakReference: ConnectionObserver?
}
