//
//  Interaction.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-01.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
 A more specific Queueable for operations such as, discovering, reading, writing, and listening to characteristics.
 */
protocol Operation: Queueable {

    var peripheral: CBPeripheral { get }

}
