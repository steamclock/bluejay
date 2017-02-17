//
//  Disconnection.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-10.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class Disconnection: Connection {
    
    override func start() {
        log.debug("Starting operation: Disconnection")
        
        state = .running
        
        manager.cancelPeripheralConnection(peripheral)
    }
    
    override func process(event: Event) {
        log.debug("Processing operation: Disconnection")
        
        if case .didDisconnectPeripheral(let peripheral) = event {
            success(peripheral)
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
}
