//
//  Connection.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

var standardConnectOptions: [String : AnyObject] = [
    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true as AnyObject,
    CBConnectPeripheralOptionNotifyOnConnectionKey: true as AnyObject
]

class Connection: Queueable {
    
    var state: QueueableState
    
    var peripheral: CBPeripheral
    var manager: CBCentralManager
    
    var callback: ((ConnectionResult) -> Void)?
    
    init(peripheral: CBPeripheral, manager: CBCentralManager, callback: @escaping (ConnectionResult) -> Void) {
        self.state = .notStarted
        
        self.peripheral = peripheral
        self.manager = manager
        
        self.callback = callback
    }
    
    func start() {
        state = .running
        manager.connect(peripheral, options: standardConnectOptions)
    }
    
    func process(event: Event) {        
        if case .didConnectPeripheral(let peripheral) = event {
            success(peripheral)
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func success(_ peripheral: CBPeripheral) {
        state = .completed
        
        callback?(.success(peripheral))
        callback = nil
    }
    
    func fail(_ error: NSError) {
        state = .failed(error)

        callback?(.failure(error))
        callback = nil        
    }
    
}
