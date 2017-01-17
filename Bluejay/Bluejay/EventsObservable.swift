//
//  EventsObservable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
    A protocol allowing conforming objects registered to Bluejay to optionally respond to Bluetooth connection events.
 
    - Attention
    On initial subscription to Bluetooth events, `bluetoothAvailable(_ available: Bool)` will always be called immediately with whatever the current state is, and `connected(_ peripheral: BluejayPeripheral)` will also be called immediately if a device is already connected.

    - Note
    Available callbacks:
    * `func bluetoothAvailable(_ available: Bool)`
    * `func connected(_ peripheral: BluejayPeripheral)`
    * `func disconected()`
*/
public protocol EventsObservable: class {
    
    /**
        Called whenever Bluetooth availability changes, as well as when an object first subscribes to observing Bluetooth events.
    */
    func bluetoothAvailable(_ available: Bool)
    func connected(_ peripheral: Peripheral)
    func disconected()
}

/// Slightly less gross way to make the BluejayEventsObservable protocol's functions optional.
extension EventsObservable {
    public func bluetoothAvailable(_ available: Bool) {}
    public func connected(_ peripheral: Peripheral) {}
    public func disconected() {}
}

/// Allows creating weak references to BluejayEventsObservable objects, so that the Bluejay singleton does not prevent the deallocation of those objects.
struct WeakEventsObservable {
    weak var weakReference: EventsObservable?
}
