//
//  DiscoverCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class DiscoverCharacteristic: Operation {
    
    var state = OperationState.notStarted    
    var peripheral: CBPeripheral
    
    private var characteristicIdentifier: CharacteristicIdentifier
    private var callback: ((Bool) -> Void)?
    
    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, callback: @escaping (Bool) -> Void) {
        self.characteristicIdentifier = characteristicIdentifier
        self.peripheral = peripheral
        self.callback = callback
    }
    
    func start() {
        // log.debug("Starting operation: DiscoverCharacteristic")

        guard let service = peripheral.service(with: characteristicIdentifier.service.uuid) else {
            fail(Error.missingServiceError(characteristicIdentifier.service))
            return
        }
        
        if service.characteristic(with: characteristicIdentifier.uuid) != nil {
            success()
        }
        else {
            state = .running
            
            peripheral.discoverCharacteristics([characteristicIdentifier.uuid], for: service)
        }
    }
    
    func process(event: Event) {
        // log.debug("Processing operation: DiscoverCharacteristic")

        guard let service = peripheral.service(with: characteristicIdentifier.service.uuid) else {
            fail(Error.missingServiceError(characteristicIdentifier.service))
            return
        }
        
        if case .didDiscoverCharacteristics = event {
            if service.characteristic(with: characteristicIdentifier.uuid) == nil {
                fail(Error.missingCharacteristicError(characteristicIdentifier))
            }
            else {
                success()
            }
        }
        else {
            precondition(false, "Unexpected event response: \(event)")
        }
    }
    
    func success() {
        state = .completed
        
        callback?(true)
        callback = nil
    }
    
    func fail(_ error: NSError) {
        state = .failed(error)

        callback?(false)
        callback = nil        
    }
    
}
