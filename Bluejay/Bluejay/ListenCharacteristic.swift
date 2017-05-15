//
//  ListenCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class ListenCharacteristic: Operation {
    
    var queue: Queue?
    var state: QueueableState
    
    var peripheral: CBPeripheral
    
    var characteristicIdentifier: CharacteristicIdentifier
    var value: Bool
    
    private var callback: ((WriteResult) -> Void)?
    
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
    }
    
    func process(event: Event) {        
        if case .didUpdateCharacteristicNotificationState(let updated) = event {
            if updated.uuid != characteristicIdentifier.uuid {
                preconditionFailure(
                    "Expecting notification state update to charactersitic: \(characteristicIdentifier.uuid), but actually updated: \(updated.uuid)"
                )
            }
            
            state = .completed
            
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
