//
//  Disconnection.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-10.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class Disconnection: Queueable {
    
    var queue: Queue?
    var state: QueueableState
    
    let peripheral: CBPeripheral
    let manager: CBCentralManager
    
    var callback: ((ConnectionResult) -> Void)?
    
    init(peripheral: CBPeripheral, manager: CBCentralManager, callback: @escaping (ConnectionResult) -> Void) {
        self.state = .notStarted
        
        self.peripheral = peripheral
        self.manager = manager
        
        self.callback = callback
    }
    
    func start() {
        state = .running
        manager.cancelPeripheralConnection(peripheral)
        
        log("Started disconnecting from \(peripheral.name ?? peripheral.identifier.uuidString)")
    }
    
    func process(event: Event) {
        if case .didDisconnectPeripheral(let peripheral) = event {
            success(peripheral)
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func success(_ peripheral: CBPeripheral) {
        state = .completed
        
        log("Disconnected from: \(peripheral.name ?? peripheral.identifier.uuidString).")
        
        callback?(.success(peripheral))
        callback = nil
        
        updateQueue()
    }

    func cancel() {
        cancelled()
    }
    
    func cancelled() {
        state = .cancelled
        
        log("Cancelled disconnection from: \(peripheral.name ?? peripheral.identifier.uuidString).")
        
        callback?(.cancelled)
        callback = nil
        
        updateQueue()
    }
    
    func fail(_ error: NSError) {
        state = .failed(error)
        
        log("Failed disconnecting from: \(peripheral.name ?? peripheral.identifier.uuidString) with error: \(error.localizedDescription)")
        
        callback?(.failure(error))
        callback = nil
        
        updateQueue()
    }
    
}
