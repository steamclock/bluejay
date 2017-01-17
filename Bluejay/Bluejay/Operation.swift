//
//  Operation.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol Operation {
    
    var state: OperationState { get }
    
    func start(_ peripheral: CBPeripheral)
    func receivedEvent(_ event: Event, peripheral: CBPeripheral)
    func fail(_ error: NSError)
    
}
