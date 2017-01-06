//
//  WriteCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class WriteCharacteristic<T : BluejaySendable> : BluejayOperation {
    
    var state = BluejayOperationState.notStarted
    
    private var characteristicIdentifier: CharacteristicIdentifier
    private var value: T
    private var callback: ((BluejayWriteResult) -> Void)?
    
    init(characteristicIdentifier : CharacteristicIdentifier, value: T, callback: ((BluejayWriteResult) -> Void)?) {
        self.characteristicIdentifier = characteristicIdentifier
        self.callback = callback
        self.value = value
    }
    
    func start(_ peripheral: CBPeripheral) {
        guard
            let service = peripheral.service(with: characteristicIdentifier.service.uuid),
            let characteristic = service.characteristic(with: characteristicIdentifier.uuid)
        else {
            fail(BluejayErrors.missingCharacteristicError(characteristicIdentifier))
            return
        }
        
        state = .running
        peripheral.writeValue(value.toBluetoothData(), for: characteristic, type: .withResponse)
    }
    
    func receivedEvent(_ event: BluejayEvent, peripheral: CBPeripheral) {
        if case .didWriteCharacteristic(let wroteTo) = event {
            if wroteTo.uuid != characteristicIdentifier.uuid {
                preconditionFailure("Expecting write to charactersitic: \(characteristicIdentifier.uuid), but actually wrote to: \(wroteTo.uuid)")
            }
            
            callback?(.success)
            state = .completed
        }
        else {
            preconditionFailure("Expecting write to characteristic: \(characteristicIdentifier.uuid), but received event: \(event)")
        }
    }
    
    func fail(_ error : NSError) {
        callback?(.failure(error))
        state = .failed(error)
    }
    
}
