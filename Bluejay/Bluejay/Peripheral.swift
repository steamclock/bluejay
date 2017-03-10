//
//  Peripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftyUserDefaults

public class Peripheral: NSObject {
    
    // MARK: Properties
    
    private(set) var cbPeripheral: CBPeripheral
    
    fileprivate var listeners: [CharacteristicIdentifier : (ReadResult<Data?>) -> Void] = [:]
    fileprivate var listenersBeingCancelled: [CharacteristicIdentifier] = []
    
    fileprivate var observers: [WeakRSSIObserver] = []
    
    // MARK: - Initialization
    
    init(cbPeripheral: CBPeripheral) {
        self.cbPeripheral = cbPeripheral
        super.init()
        self.cbPeripheral.delegate = self
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
        
        listeners = [:]
        
        Queue.shared.cancelAll(error)
    }
    
    private func updateOperations() {
        if cbPeripheral.state == .disconnected {
            Queue.shared.cancelAll(Error.notConnectedError())
            return
        }
        
        Queue.shared.update()
    }
    
    private func addOperation(_ operation: Operation) {
        Queue.shared.add(operation: operation)
    }
    
    /// Queue the necessary operations needed to discover the specified characteristic.
    private func discoverCharactersitic(_ characteristicIdentifier: CharacteristicIdentifier, callback: @escaping (Bool) -> Void) {
        addOperation(DiscoverService(serviceIdentifier: characteristicIdentifier.service, peripheral: cbPeripheral, callback: { [weak self] success in
            guard let weakSelf = self else {
                return
            }
            
            if success {
                weakSelf.addOperation(DiscoverCharacteristic(
                    characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, callback: { success in
                        if success {
                            callback(true)
                        }
                        else {
                            callback(false)
                        }
                }))
            }
            else {
                callback(false)
            }
        }))
    }
    
    // MARK: - Bluetooth Event
    
    fileprivate func handleEvent(_ event: Event, error: NSError?) {
        if error == nil {
            Queue.shared.process(event: event, error: error)
            updateOperations()
        }
        else {
            cancelAllOperations(error ?? Error.unknownError())
        }
    }
    
    // MARK: - RSSI Event
    
    public func readRSSI() {
        cbPeripheral.readRSSI()
    }
    
    public func register(observer: RSSIObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
        observers.append(WeakRSSIObserver(weakReference: observer))
    }
    
    public func unregister(observer: RSSIObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
    }
    
    // MARK: - Actions
    
    /// Read from a specified characteristic.
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        precondition(
            listeners[characteristicIdentifier] == nil,
            "Cannot read from characteristic: \(characteristicIdentifier.uuid), which is already being listened on."
        )
        
        log.debug("Queueing read to: \(characteristicIdentifier.uuid.uuidString)")
        
        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] success in
            guard let weakSelf = self else {
                return
            }
            
            if success {
                weakSelf.addOperation(
                    ReadCharacteristic(characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, callback: completion)
                )
            }
            else {
                completion(.failure(Error.missingCharacteristicError(characteristicIdentifier)))
            }
        })
    }
    
    /// Write to a specified characteristic.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (WriteResult) -> Void) {
        log.debug("Queueing write to: \(characteristicIdentifier.uuid.uuidString) with value of: \(value)")
        
        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] success in
            guard let weakSelf = self else {
                return
            }
            
            // Not using the success variable here because the write operation will also catch the error if the service or the characteristic is not discovered.
            weakSelf.addOperation(
                WriteCharacteristic(characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, value: value, callback: completion))
        })
    }
    
    /// Listen for notifications on a specified characterstic.
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        log.debug("Start listening: \(characteristicIdentifier.uuid.uuidString)")
        
        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] success in
            guard let weakSelf = self else {
                return
            }
            
            // Not using the success variable here because the listen operation will also catch the error if the service or the characteristic is not discovered.
            weakSelf.addOperation(
                ListenCharacteristic(characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, value: true, callback: { result in
                precondition(
                    weakSelf.listeners[characteristicIdentifier] == nil,
                    "Cannot have multiple active listens against the same characteristic: \(characteristicIdentifier.uuid)"
                )
                
                switch result {
                case .success:
                    log.debug("Listen successful: \(characteristicIdentifier.uuid.uuidString)")
                    
                    weakSelf.listeners[characteristicIdentifier] = { dataResult in
                        completion(ReadResult<R>(dataResult: dataResult))
                    }
                    
                    // Make sure a successful listen is cached, so Bluejay can inform which characteristics need their listens restored on state restoration.
                    weakSelf.cache(listeningCharacteristic: characteristicIdentifier)
                case .failure(let error):
                    log.debug("Listen failed: \(characteristicIdentifier.uuid.uuidString)")
                    
                    completion(.failure(error))
                }
            }))
        })
    }
    
    /**
     End listening on a specified characteristic.
     
     Provides the ability to suppress the failure message to the listen callback. This is useful in the internal implimentation of some of the listening logic, since we want to be able to share the clear logic on a .done exit, but don't need to send a failure in that case.
     
     - Note
     Currently this can also cancel a regular in-progress read as well, but that behaviour may change down the road.
     */
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, sendFailure: Bool, completion: ((WriteResult) -> Void)? = nil) {
        log.debug("Ending listen: \(characteristicIdentifier.uuid.uuidString)")
        
        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] success in
            guard let weakSelf = self else {
                return
            }
            
            weakSelf.listenersBeingCancelled.append(characteristicIdentifier)
            
            // Not using the success variable here because the listen operation will also catch the error if the service or the characteristic is not discovered.
            weakSelf.addOperation(
                ListenCharacteristic(characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, value: false, callback: { result in
                let listenCallback = weakSelf.listeners[characteristicIdentifier]
                weakSelf.listeners[characteristicIdentifier] = nil
                
                if(sendFailure) {
                    log.debug("Sending listeners an error for ending the listen on: \(characteristicIdentifier.uuid.uuidString)")
                    listenCallback?(.failure(Error.cancelledError()))
                }
                
                log.debug("Ending of listen successful: \(characteristicIdentifier.uuid.uuidString)")
                
                completion?(result)
                
                // Make sure a cancelled listen does not exist in the cache, as we don't want to restore a cancelled listen on state restoration.
                weakSelf.remove(listeningCharacteristic: characteristicIdentifier)
            }))
        })
    }
    
    /// Restore a (believed to be) active listening session, so if we start up in response to a notification, we can receive it.
    public func restoreListen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        precondition(
            listeners[characteristicIdentifier] == nil,
            "Cannot have multiple active listens against the same characteristic"
        )
        
        listeners[characteristicIdentifier] = { dataResult in
            completion(ReadResult<R>(dataResult: dataResult))
        }
        
        // Make sure restored listens are cached again for future restoration. The cache method will handle any duplicate uuid, so this sanity check should not create any redundancy.
        cache(listeningCharacteristic: characteristicIdentifier)
    }
    
    private func cache(listeningCharacteristic: CharacteristicIdentifier) {
        let serviceUuid = listeningCharacteristic.service.uuid.uuidString
        let characteristicUuid = listeningCharacteristic.uuid.uuidString
        
        log.debug("Adding cached listen: \(characteristicUuid) for service: \(serviceUuid)")
        
        Defaults[.listeningCharacteristics][serviceUuid] = characteristicUuid
        
        // Don't want to open up any possibilities where the defaults are not saved immediately.
        Defaults.synchronize()
        
        log.debug("Current cached listens: \(Defaults[.listeningCharacteristics])")
    }
    
    private func remove(listeningCharacteristic: CharacteristicIdentifier) {
        let serviceUuid = listeningCharacteristic.service.uuid.uuidString
        let characteristicUuid = listeningCharacteristic.uuid.uuidString
        
        log.debug("Removing cached listen: \(characteristicUuid) for service: \(serviceUuid)")
        
        Defaults[.listeningCharacteristics][serviceUuid] = nil
        
        // Don't want to open up any possibilities where the defaults are not saved immediately.
        Defaults.synchronize()
        
        listenersBeingCancelled = listenersBeingCancelled.filter { (characteristicIdentifier) -> Bool in
            return characteristicIdentifier.uuid.uuidString != listeningCharacteristic.uuid.uuidString
        }
        
        log.debug("Current cached listens: \(Defaults[.listeningCharacteristics])")
    }
}

// MARK: - CBPeripheralDelegate

extension Peripheral: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Swift.Error?) {
        handleEvent(.didDiscoverServices, error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Swift.Error?) {
        handleEvent(.didDiscoverCharacteristics, error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Swift.Error?) {
        handleEvent(.didWriteCharacteristic(characteristic), error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Swift.Error?) {
        guard let listener = listeners[CharacteristicIdentifier(characteristic)] else {
            
            // Handle attempting to read a characteristic whose listen is being cancelled during state restoration.
            let isCancellingListenOnCurrentRead = listenersBeingCancelled.contains(where: { (characteristicIdentifier) -> Bool in
                return characteristicIdentifier.uuid.uuidString == characteristic.uuid.uuidString
            })
            
            let isReadUnhandled = isCancellingListenOnCurrentRead || Queue.shared.isEmpty()
            
            if isReadUnhandled {
                return
            }
            else {
                handleEvent(.didReadCharacteristic(characteristic, characteristic.value ?? Data()), error: error as NSError?)
                return
            }
        }
        
        if let error = error {
            listener(.failure(error))
        }
        else {
            listener(.success(characteristic.value))
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Swift.Error?) {
        handleEvent(.didUpdateCharacteristicNotificationState(characteristic), error: error as NSError?)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Swift.Error?) {
        for observer in observers {
            observer.weakReference?.peripheral(peripheral, didReadRSSI: RSSI, error: error)
        }
    }
    
}
