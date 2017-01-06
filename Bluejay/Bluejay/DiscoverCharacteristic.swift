//
//  DiscoverCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class DiscoverCharacteristic: BluejayOperation {
    
    var state = BluejayOperationState.notStarted
    
    private var characteristicIdentifier: CharacteristicIdentifier
    
    init(characteristicIdentifier: CharacteristicIdentifier) {
        self.characteristicIdentifier = characteristicIdentifier
    }
    
    func start(_ peripheral: CBPeripheral) {
        guard let service = peripheral.service(with: characteristicIdentifier.service.uuid) else {
            fail(BluejayErrors.missingServiceError(characteristicIdentifier.service))
            return
        }
        
        if service.characteristic(with: characteristicIdentifier.uuid) != nil {
            state = .completed
        }
        else {
            state = .running
            peripheral.discoverCharacteristics([characteristicIdentifier.uuid], for: service)
        }
    }
    
    func receivedEvent(_ event: BluejayEvent, peripheral: CBPeripheral) {
        guard let service = peripheral.service(with: characteristicIdentifier.service.uuid) else {
            fail(BluejayErrors.missingServiceError(characteristicIdentifier.service))
            return
        }
        
        if case .didDiscoverCharacteristics = event {
            if service.characteristic(with: characteristicIdentifier.uuid) == nil {
                fail(BluejayErrors.missingCharacteristicError(characteristicIdentifier))
            }
            else {
                state = .completed
            }
        }
        else {
            precondition(false, "unexpected event response: \(event)")
        }
    }
    
    func fail(_ error : NSError) {
        // TODO: Add missing error handling.
    }
    
}
