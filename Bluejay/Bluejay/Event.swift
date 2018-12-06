//
//  Event.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/// The available events a queue can and should respond to.
enum Event {
    case didDiscoverServices
    case didDiscoverCharacteristics
    case didDiscoverPeripheral(CBPeripheral, [String: Any], NSNumber)
    case didConnectPeripheral(Peripheral)
    case didDisconnectPeripheral(Peripheral)
    case didReadCharacteristic(CBCharacteristic, Data)
    case didWriteCharacteristic(CBCharacteristic)
    case didUpdateCharacteristicNotificationState(CBCharacteristic)
}
