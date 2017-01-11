//
//  BluejayPeripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

public class BluejayPeripheral: NSObject {
    
    // MARK: Properties
    
    private(set) var cbPeripheral: CBPeripheral
    fileprivate var listeners: [CharacteristicIdentifier : (BluejayReadResult<Data?>) -> Void] = [:]
    private var operations: [BluejayOperation] = []
    
    // MARK: - Initialization
    
    init(cbPeripheral: CBPeripheral) {
        self.cbPeripheral = cbPeripheral
        super.init()
        cbPeripheral.delegate = self
    }
    
    // MARK: - Attributes
    
    public var uuid: PeripheralIdentifier {
        return PeripheralIdentifier(uuid: cbPeripheral.identifier)
    }
    
    public var name: String? {
        return cbPeripheral.name
    }
    
    // MARK: - Operations
    
    func cancelAllOperations(_ error: NSError) {
        for callback in listeners.values {
            callback(.failure(error))
        }
        
        for operation in operations {
            operation.fail(error)
        }
        
        listeners = [:]
        operations = []
    }
    
    private func updateOperations() {
        if cbPeripheral.state == .disconnected {
            cancelAllOperations(BluejayError.notConnectedError())
            return
        }
        
        while operations.count > 0 {
            switch operations[0].state {
            case .notStarted:
                operations[0].start(cbPeripheral)
            case .running:
                return
            case .failed(let error):
                operations.removeFirst()
                cancelAllOperations(error)
            case .completed:
                operations.removeFirst()
            }
        }
    }
    
    private func addOperation(_ operation: BluejayOperation) {
        operations.append(operation)
        updateOperations()
    }
    
    /// Queue the necessary operations needed to discover the specified characteristic.
    private func discoverCharactersitic(_ characteristicIdentifier: CharacteristicIdentifier) {
        addOperation(DiscoverService(serviceIdentifier: characteristicIdentifier.service))
        addOperation(DiscoverCharacteristic(characteristicIdentifier: characteristicIdentifier))
    }
    
    // MARK: - Bluetooth Event
    
    fileprivate func handleEvent(_ event: BluejayEvent, error: NSError?) {
        precondition(operations.count > 0)
        
        if error == nil {
            operations[0].receivedEvent(event, peripheral: cbPeripheral)
            updateOperations()
        }
        else {
            cancelAllOperations(error ?? BluejayError.unknownError())
        }
    }
    
    // MARK: - Actions
    
    /// Read from a specified characteristic.
    public func read<R: BluejayReceivable>(from characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (BluejayReadResult<R>) -> Void) {
        precondition(
            listeners[characteristicIdentifier] == nil,
            "Cannot read from characteristic: \(characteristicIdentifier.uuid), which is already being listened on."
        )
        
        discoverCharactersitic(characteristicIdentifier)
        addOperation(ReadCharacteristic(characteristicIdentifier: characteristicIdentifier, callback: completion))
    }
    
    /// Write to a specified characteristic.
    public func write<S: BluejaySendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (BluejayWriteResult) -> Void) {
        discoverCharactersitic(characteristicIdentifier)
        addOperation(WriteCharacteristic(characteristicIdentifier: characteristicIdentifier, value: value, callback: completion))
    }
    
    /// Listen for notifications on a specified characterstic.
    public func listen<R: BluejayReceivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (BluejayReadResult<R>) -> Void) {
        log.debug("Start listening: \(characteristicIdentifier.uuid.uuidString)")
        
        discoverCharactersitic(characteristicIdentifier)
        
        addOperation(ListenCharacteristic(characteristicIdentifier: characteristicIdentifier, value: true, callback: { result in
            precondition(
                self.listeners[characteristicIdentifier] == nil,
                "Cannot have multiple active listens against the same characteristic: \(characteristicIdentifier.uuid)"
            )
            
            switch result {
            case .success:
                log.debug("Listen successful: \(characteristicIdentifier.uuid.uuidString)")
                
                self.listeners[characteristicIdentifier] = { dataResult in
                    completion(BluejayReadResult<R>(dataResult: dataResult))
                }
            case .failure(let error):
                log.debug("Listen failed: \(characteristicIdentifier.uuid.uuidString)")
                
                completion(.failure(error))
            }
        }))
    }
    
    /**
        Cancel listening on a specified characteristic.
     
        Provides the ability to suppress the failure message to the listen callback. This is useful in the internal implimentation of some of the listening logic, since we want to be able to share the clear logic on a .done exit, but don't need to send a failure in that case.
     
        - Note
        Currently this can also cancel a regular in-progress read as well, but that behaviour may change down the road.
    */
    public func cancelListen(to characteristicIdentifier: CharacteristicIdentifier, sendFailure: Bool, completion: ((BluejayWriteResult) -> Void)? = nil) {
        log.debug("Start cancelling listen: \(characteristicIdentifier.uuid.uuidString)")
        
        discoverCharactersitic(characteristicIdentifier)
        
        addOperation(ListenCharacteristic(characteristicIdentifier: characteristicIdentifier, value: false, callback: { result in
            let listenCallback = self.listeners[characteristicIdentifier]
            self.listeners[characteristicIdentifier] = nil
            
            if(sendFailure) {
                log.debug("Sending listeners an error for cancelling the listen on: \(characteristicIdentifier.uuid.uuidString)")
                listenCallback?(.failure(BluejayError.cancelledError()))
            }
            
            log.debug("Cancellation of listen successful: \(characteristicIdentifier.uuid.uuidString)")
            
            completion?(result)
        }))
    }
    
    /// Restore a (believed to be) active listening session, so if we start up in response to a notification, we can receive it.
    public func restoreListen<R: BluejayReceivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (BluejayReadResult<R>) -> Void) {
        precondition(
            listeners[characteristicIdentifier] == nil,
            "Cannot have multiple active listens against the same characteristic"
        )
        
        listeners[characteristicIdentifier] = { dataResult in
            completion(BluejayReadResult<R>(dataResult: dataResult))
        }
    }
    
}

// MARK: - CBPeripheralDelegate

extension BluejayPeripheral: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        handleEvent(.didDiscoverServices, error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        handleEvent(.didDiscoverCharacteristics, error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        handleEvent(.didWriteCharacteristic(characteristic), error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let listener = listeners[CharacteristicIdentifier(characteristic)] else {
            handleEvent(.didReadCharacteristic(characteristic, characteristic.value ?? Data()), error: error as NSError?)
            return
        }
        
        if let error = error {
            listener(.failure(error))
        }
        else {
            listener(.success(characteristic.value))
        }        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        handleEvent(.didUpdateCharacteristicNotificationState(characteristic), error: error as NSError?)
    }
    
}
