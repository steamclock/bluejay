//
//  Operation.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol Operation: Queueable {
    
    var peripheral: CBPeripheral { get }
    
}
