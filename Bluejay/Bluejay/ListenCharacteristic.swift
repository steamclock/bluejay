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
    
    var state = OperationState.notStarted
    
    private var characteristicIdentifier: CharacteristicIdentifier
    private var value: Bool
    private var callback: ((WriteResult) -> Void)?
    
    init(characteristicIdentifier: CharacteristicIdentifier, value: Bool, callback: ((WriteResult) -> Void)?) {
        self.characteristicIdentifier = characteristicIdentifier
        self.callback = callback
        self.value = value
    }
    
    func start(_ peripheral: CBPeripheral) {
        guard
            let service = peripheral.service(with: characteristicIdentifier.service.uuid),
            let characteristic = service.characteristic(with: characteristicIdentifier.uuid)
        else {
            fail(Error.missingCharacteristicError(characteristicIdentifier))
            return
        }
        
        state = .running
        peripheral.setNotifyValue(value, for: characteristic)
    }
    
    func receivedEvent(_ event: Event, peripheral: CBPeripheral) {
        if case .didUpdateCharacteristicNotificationState(let updated) = event {
            if updated.uuid != characteristicIdentifier.uuid {
                preconditionFailure(
                    "Expecting notification state update to charactersitic: \(characteristicIdentifier.uuid), but actually updated: \(updated.uuid)"
                )
            }
            
            callback?(.success)
            state = .completed
        }
        else {
            preconditionFailure(
                "Expecting notification state update to charactersitic: \(characteristicIdentifier.uuid), but received event: \(event)"
            )
        }
    }
    
    func fail(_ error: NSError) {
        callback?(.failure(error))
        state = .failed(error)
    }
    
}
