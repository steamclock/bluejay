//
//  ListenCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A listen operation.
class ListenCharacteristic: Operation {
    
    /// The queue this operation belongs to.
    var queue: Queue?
    
    /// The state of this operation.
    var state: QueueableState
    
    /// The peripheral this operation is for.
    var peripheral: CBPeripheral
    
    /// The characteristic to listen to.
    var characteristicIdentifier: CharacteristicIdentifier
    
    /// Whether to start listening or to stop listening.
    var value: Bool
    
    /// Callback for the attempt to start or stop listening, not the values received from the characteristic.
    private var callback: ((WriteResult) -> Void)?
    
    /// Internal reference to the CBCharacteristic. 
    private var characteristic: CBCharacteristic?
    
    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, value: Bool, callback: @escaping (WriteResult) -> Void) {
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
        
        peripheral.setNotifyValue(value, for: characteristic)
        
        self.characteristic = characteristic
        
        if value {
            log("Will start listening to \(characteristicIdentifier.uuid) on \(peripheral.name ?? peripheral.identifier.uuidString).")
        }
        else {
            log("Will stop listening to \(characteristicIdentifier.uuid) on \(peripheral.name ?? peripheral.identifier.uuidString).")
        }
    }
    
    func process(event: Event) {        
        if case .didUpdateCharacteristicNotificationState(let updated) = event {
            if updated.uuid != characteristicIdentifier.uuid {
                preconditionFailure(
                    "Expecting notification state update to charactersitic: \(characteristicIdentifier.uuid), but actually updated: \(updated.uuid)"
                )
            }
            
            state = .completed
            
            if value {
                log("Listening to \(characteristicIdentifier.uuid) on \(peripheral.name ?? peripheral.identifier.uuidString).")
            }
            else {
                log("Stopped listening to \(characteristicIdentifier.uuid) on \(peripheral.name ?? peripheral.identifier.uuidString).")
            }
            
            callback?(.success)
            callback = nil
            
            updateQueue()
        }
        else {
            preconditionFailure(
                "Expecting notification state update to charactersitic: \(characteristicIdentifier.uuid), but received event: \(event)"
            )
        }
    }
    
    func cancel() {
        cancelled()
    }
    
    func cancelled() {
        state = .cancelled
        
        if let characteristic = characteristic {
            peripheral.setNotifyValue(false, for: characteristic)
        }
        
        log("Cancelled listen to \(characteristicIdentifier.uuid) on \(peripheral.name ?? peripheral.identifier.uuidString).")
        
        callback?(.cancelled)
        callback = nil
        
        updateQueue()
    }
    
    func fail(_ error: NSError) {
        state = .failed(error)
        
        log("Failed listening to \(characteristicIdentifier.uuid) on \(peripheral.name ?? peripheral.identifier.uuidString) with error: \(error.localizedDescription)")
        
        callback?(.failure(error))
        callback = nil
        
        updateQueue()
    }
    
}
