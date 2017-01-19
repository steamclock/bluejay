//
//  ScanService.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class ScanService: Connection {
    
    var state = OperationState.notStarted
    var manager: CBCentralManager
    
    private let serviceIdentifier: ServiceIdentifier
    private let callback: (ConnectionResult) -> Void
    
    init(serviceIdentifier: ServiceIdentifier, manager: CBCentralManager, callback: @escaping (ConnectionResult) -> Void) {
        self.serviceIdentifier = serviceIdentifier
        self.manager = manager
        self.callback = callback
    }
    
    func start() {
        log.debug("Starting operation: ScanService")
        
        state = .running
        manager.scanForPeripherals(withServices: [serviceIdentifier.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
    }
    
    func process(event: Event) {
        log.debug("Processing operation: ScanService")

        if case .didDiscoverPeripheral(let peripheral) = event {
            manager.stopScan()
            callback(.success(Peripheral(cbPeripheral: peripheral)))
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
