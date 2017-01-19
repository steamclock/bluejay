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
    
    init(serviceIdentifier: ServiceIdentifier, peripheral: CBPeripheral) {
        self.serviceIdentifier = serviceIdentifier
        self.peripheral = peripheral
    }
    
    func start() {
        if peripheral.service(with: serviceIdentifier.uuid) != nil {
            state = .completed
        }
        else {
            state = .running
            peripheral.discoverServices([serviceIdentifier.uuid])
        }
    }
    
    func process(event: Event) {
        if case .didDiscoverServices = event {
            if peripheral.service(with: serviceIdentifier.uuid) == nil {
                fail(Error.missingServiceError(serviceIdentifier))
            }
            else {
                state = .completed
            }
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func fail(_ error : NSError) {
        // TODO: Add missing error handling.
    }
    
}
