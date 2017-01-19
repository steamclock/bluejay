//
//  WriteCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class WriteCharacteristic<T: Sendable>: Operation {
    
    var state = OperationState.notStarted
    var peripheral: CBPeripheral
    
    private var characteristicIdentifier: CharacteristicIdentifier
    private var value: T
    private var callback: ((WriteResult) -> Void)?
    
    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, value: T, callback: ((WriteResult) -> Void)?) {
        self.characteristicIdentifier = characteristicIdentifier
        self.peripheral = peripheral
        self.value = value
        self.callback = callback
    }
    
    func start() {
        log.debug("Starting operation: WriteCharacteristic")

        guard
            let service = peripheral.service(with: characteristicIdentifier.service.uuid),
            let characteristic = service.characteristic(with: characteristicIdentifier.uuid)
        else {
            fail(Error.missingCharacteristicError(characteristicIdentifier))
            return
        }
        
        state = .running
        peripheral.writeValue(value.toBluetoothData(), for: characteristic, type: .withResponse)
    }
    
    func process(event: Event) {
        log.debug("Processing operation: ReadCharacteristic")
        
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
    
    func fail(_ error: NSError) {
        callback?(.failure(error))
        state = .failed(error)
    }
    
}
