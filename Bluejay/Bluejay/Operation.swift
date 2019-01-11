//
//  Operation.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-01.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/// A more specific Queueable for peripheral-specific operations such as, discovering, reading, writing, and listening to characteristics.
protocol Operation: Queueable {
    var peripheral: CBPeripheral { get }
}

/// An even more specific Queueable, albeit empty, to allow specifying a read operation without having to deal with the read operation's generics.
protocol ReadOperation: Operation {}
