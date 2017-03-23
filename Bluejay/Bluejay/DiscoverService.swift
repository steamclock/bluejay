//
//  DiscoverService.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class DiscoverService: Operation {
    
    var state = OperationState.notStarted    
    var peripheral: CBPeripheral
    
    private var serviceIdentifier: ServiceIdentifier
    private var callback: ((Bool) -> Void)?

    init(serviceIdentifier: ServiceIdentifier, peripheral: CBPeripheral, callback: @escaping (Bool) -> Void) {
        self.serviceIdentifier = serviceIdentifier
        self.peripheral = peripheral
        self.callback = callback
    }
    
    func start() {
        // log.debug("Starting operation: DiscoverService")

        if peripheral.service(with: serviceIdentifier.uuid) != nil {
            success()
        }
        else {
            state = .running
            
            peripheral.discoverServices([serviceIdentifier.uuid])
        }
    }
    
    func process(event: Event) {
        // log.debug("Processing operation: DiscoverService")

        if case .didDiscoverServices = event {
            if peripheral.service(with: serviceIdentifier.uuid) == nil {
                fail(Error.missingServiceError(serviceIdentifier))
            }
            else {
                success()
            }
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func success() {
        state = .completed
        
        callback?(true)
        callback = nil
    }
    
    func fail(_ error : NSError) {
        state = .failed(error)

        callback?(false)
        callback = nil        
    }
    
}
