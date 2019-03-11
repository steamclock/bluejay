//
//  PeripheralDelegate.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-13.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/// Contractualize communication between the peripheral and its associated Bluejay instance.
protocol PeripheralDelegate: class {
    /// The peripheral requires queueing an operation.
    func requested(operation: Operation, from peripheral: Peripheral)

    /// The peripheral has received an event and requires Bluejay to process it.
    func received(event: Event, error: NSError?, from peripheral: Peripheral)

    /// The peripheral requires checking whether Bluejay is currently waiting for a characteristic to be read.
    func isReading(characteristic: CharacteristicIdentifier) -> Bool

    /// The peripheral requires checking whether Bluejay has an end listen queued for a specific characteristic.
    func willEndListen(on characteristic: CharacteristicIdentifier) -> Bool

    /// The peripheral requires checking whether Bluejay has background restoration enabled.
    func backgroundRestorationEnabled() -> Bool

    /// The peripheral has received an unhandled listen and requires Bluejay to process it.
    func receivedUnhandledListen(from peripheral: Peripheral, on characteristic: CharacteristicIdentifier, with value: Data?)

    /// The peripheral has received a RSSI value and notifies Bluejay.
    func didReadRSSI(from peripheral: Peripheral, RSSI: NSNumber, error: Error?)

    /// The peripheral's list of available services has changed.
    func didModifyServices(from peripheral: Peripheral, invalidatedServices: [ServiceIdentifier])
}
