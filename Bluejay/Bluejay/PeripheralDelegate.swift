//
//  PeripheralDelegate.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-13.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/// Contractualize communication between the peripheral its associated Bluejay instance.
protocol PeripheralDelegate: class {
    func requested(operation: Operation, from peripheral: Peripheral)
    func received(event: Event, error: NSError?, from peripheral: Peripheral)
    func isReading(characteristic: CharacteristicIdentifier) -> Bool
    func willEndListen(on characteristic: CharacteristicIdentifier) -> Bool
    func backgroundRestorationEnabled() -> Bool
    func receivedUnhandledListen(from peripheral: Peripheral, on characteristic: CharacteristicIdentifier, with value: Data?)
    func didReadRSSI(from peripheral: Peripheral, RSSI: NSNumber, error: Error?)
}
