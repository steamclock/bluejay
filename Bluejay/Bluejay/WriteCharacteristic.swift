//
//  WriteCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A write operation.
class WriteCharacteristic<T: Sendable>: Operation {
    
    /// The queue this operation belongs to.
    var queue: Queue?
    
    /// The state of this operation.
    var state: QueueableState
    
    /// The peripheral this operation is for.
    var peripheral: CBPeripheral
    
    /// The characteristic to write to.
    var characteristicIdentifier: CharacteristicIdentifier
    
    /// The value to write.
    var value: T
    
    /// Callback for the write attempt.
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
        
        log("Started write to \(characteristicIdentifier.uuid) on \(peripheral.identifier).")
    }
    
    func process(event: Event) {
        if case .didWriteCharacteristic(let wroteTo) = event {
            if wroteTo.uuid != characteristicIdentifier.uuid {
                preconditionFailure("Expecting write to charactersitic: \(characteristicIdentifier.uuid), but actually wrote to: \(wroteTo.uuid)")
            }
            
            state = .completed
            
            log("Write to \(characteristicIdentifier.uuid) on \(peripheral.identifier) is successful.")
            
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
        
        log("Cancelled write to \(characteristicIdentifier.uuid) on \(peripheral.identifier).")
        
        callback?(.cancelled)
        callback = nil
        
        updateQueue()
    }
    
    func fail(_ error: NSError) {
        state = .failed(error)
        
        log("Failed writing to \(characteristicIdentifier.uuid) on \(peripheral.identifier) with error: \(error.localizedDescription)")

        callback?(.failure(error))
        callback = nil
        
        updateQueue()
    }
    
}
