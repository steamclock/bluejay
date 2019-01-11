//
//  DisconnectHandler.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-10-11.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/**
 A protocol allowing a single delegate registered to Bluejay to have a final say at the end of a disconnection, as well as evaluate and control the auto-reconnect behaviour.
 
 - Attention: Be careful with how you organize app and Bluejay logic inside your connect, explicit disconnect, the disconnect handler callbacks. It may be easy to create redundant or conflicting code. As a rule of thumb, we recommend putting light weight and repeatable logic, such as UI updates, inside your connect and disconnect callbacks. And for more major operations such as restarting any Bluetooth tasks, use the disconnect handler.
*/
public protocol DisconnectHandler: class {
    /**
     Notifies the delegate that the peripheral is fully disconnected.
     
     - Parameters:
        - peripheral: the peripheral disconnected
        - error: the reason of the disconnection from CoreBluetooth, not Bluejay
        - autoReconnect: whether Bluejay will auto-reconnect if no change is given
    */
    func didDisconnect(
        from peripheral: PeripheralIdentifier,
        with error: Error?,
        willReconnect autoReconnect: Bool) -> AutoReconnectMode
}

/// Tells Bluejay whether it should auto-reconnect.
public enum AutoReconnectMode {
    /// Bluejay will maintain its current auto-reconnect behaviour.
    case noChange
    /// Override Bluejay's auto-reconnect behaviour.
    case change(shouldAutoReconnect: Bool)
}
