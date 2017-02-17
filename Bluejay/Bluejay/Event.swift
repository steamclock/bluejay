//
//  Event.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

enum Event {
    case didDiscoverServices
    case didDiscoverCharacteristics
    case didDiscoverPeripheral(CBPeripheral, [String : Any])
    case didConnectPeripheral(CBPeripheral)
    case didDisconnectPeripheral(CBPeripheral)
    case didReadCharacteristic(CBCharacteristic, Data)
    case didWriteCharacteristic(CBCharacteristic)
    case didUpdateCharacteristicNotificationState(CBCharacteristic)
}
