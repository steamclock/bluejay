//
//  ConnectPeripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class ConnectPeripheral: Connection {
    
    private var standardConnectOptions: [String : AnyObject] = [
        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true as AnyObject,
        CBConnectPeripheralOptionNotifyOnConnectionKey: true as AnyObject
    ]
    
    var state = OperationState.notStarted
    var manager: CBCentralManager
    
    private let peripheral: CBPeripheral
    private let callback: (ConnectionResult) -> Void
    
    init(peripheral: CBPeripheral, manager: CBCentralManager, callback: @escaping (ConnectionResult) -> Void) {
        self.peripheral = peripheral
        self.manager = manager
        self.callback = callback
    }
    
    func start() {
        log.debug("Starting operation: ConnectPeripheral")
        
        state = .running
        manager.connect(peripheral, options: standardConnectOptions)
    }
    
    func process(event: Event) {
        log.debug("Processing operation: ConnectPeripheral")
        
        if case .didConnectPeripheral(let peripheral) = event {
            callback(.success(peripheral))
            state = .completed
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func fail(_ error : NSError) {
        callback(.failure(error))
        state = .failed(error)
    }
    
}
