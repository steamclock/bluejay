//
//  DiscoverService.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class DiscoverService: BluejayOperation {
    
    var state = BluejayOperationState.notStarted
    
    private var serviceIdentifier : ServiceIdentifier
    
    init(serviceIdentifier: ServiceIdentifier) {
        self.serviceIdentifier = serviceIdentifier
    }
    
    func start(_ peripheral: CBPeripheral) {
        if peripheral.service(with: serviceIdentifier.uuid) != nil {
            state = .completed
        }
        else {
            state = .running
            peripheral.discoverServices([serviceIdentifier.uuid])
        }
    }
    
    func receivedEvent(_ event: BluejayEvent, peripheral: CBPeripheral) {
        if case .didDiscoverServices = event {
            if peripheral.service(with: serviceIdentifier.uuid) == nil {
                fail(BluejayError.missingServiceError(serviceIdentifier))
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
