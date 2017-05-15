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
    
    var queue: Queue?
    var state: QueueableState
    
    var peripheral: CBPeripheral
    
    var characteristicIdentifier: CharacteristicIdentifier
    var value: T
    
    private var callback: ((WriteResult) -> Void)?
    
    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, value: T, callback: @escaping (WriteResult) -> Void) {
        self.state = .notStarted
        
        self.characteristicIdentifier = characteristicIdentifier
        self.peripheral = peripheral
        self.value = value
        self.callback = callback
    }
    
    func start() {
        guard
            let service = peripheral.service(with: characteristicIdentifier.service.uuid),
            let characteristic = service.characteristic(with: characteristicIdentifier.uuid)
        else {
            fail(Error.missingCharacteristic(characteristicIdentifier))
            return
        }
        
        state = .running
        
        peripheral.writeValue(value.toBluetoothData(), for: characteristic, type: .withResponse)
    }
    
    func process(event: Event) {
        if case .didWriteCharacteristic(let wroteTo) = event {
            if wroteTo.uuid != characteristicIdentifier.uuid {
                preconditionFailure("Expecting write to charactersitic: \(characteristicIdentifier.uuid), but actually wrote to: \(wroteTo.uuid)")
            }
            
            state = .completed
            
            callback?(.success)
            callback = nil
            
            updateQueue()
        }
        else {
            preconditionFailure("Expecting write to characteristic: \(characteristicIdentifier.uuid), but received event: \(event)")
        }
    }
    
    func cancel() {
        cancelled()
    }
    
    func cancelled() {
        state = .cancelled
        
        callback?(.cancelled)
        callback = nil
        
        updateQueue()
    }
    
    func fail(_ error: NSError) {
        state = .failed(error)

        callback?(.failure(error))
        callback = nil
        
        updateQueue()
    }
    
}
