//
//  Peripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

public class Peripheral: NSObject {
    
    // MARK: Properties
    
    private(set) weak var bluejay: Bluejay?
    private(set) var cbPeripheral: CBPeripheral
    
    fileprivate var listeners: [CharacteristicIdentifier : (ReadResult<Data?>) -> Void] = [:]
    fileprivate var listenersBeingCancelled: [CharacteristicIdentifier] = []
    
    fileprivate var observers: [WeakRSSIObserver] = []
    
    // MARK: - Initialization
    
    init(bluejay: Bluejay, cbPeripheral: CBPeripheral) {
        self.bluejay = bluejay
        self.cbPeripheral = cbPeripheral
        
        super.init()
        
        self.cbPeripheral.delegate = self
    }
    
    deinit {
        log("Deinit peripheral: \(String(describing: cbPeripheral.name ?? cbPeripheral.identifier.uuidString))")
    }
    
    // MARK: - Attributes
    
    public var uuid: PeripheralIdentifier {
        return PeripheralIdentifier(uuid: cbPeripheral.identifier)
    }
    
    public var name: String? {
        return cbPeripheral.name
    }
    
    // MARK: - Operations
    
    func cancelAllListens(_ error: NSError? = nil) {
        for callback in listeners.values {
            if let error = error {
                callback(.failure(error))
            }
            else {
                callback(.cancelled)
            }
        }
        
        listeners = [:]
    }
    
    private func updateOperations() {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot update operation: Bluejay is nil.")
        }
        
        if cbPeripheral.state == .disconnected {
            bluejay.queue.cancelAll(Error.notConnected())
            return
        }
        
        bluejay.queue.update()
    }
    
    private func addOperation(_ operation: Operation) {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot add operation: Bluejay is nil.")
        }
        
        bluejay.queue.add(operation)
    }
    
    /// Queue the necessary operations needed to discover the specified characteristic.
    private func discoverCharactersitic(_ characteristicIdentifier: CharacteristicIdentifier, callback: @escaping (Bool) -> Void) {
        addOperation(DiscoverService(serviceIdentifier: characteristicIdentifier.service, peripheral: cbPeripheral, callback: { [weak self] result in
            guard let weakSelf = self else {
                return
            }
            
            switch result {
            case .success:
                weakSelf.addOperation(DiscoverCharacteristic(
                    characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, callback: { result in
                        switch result {
                        case .success:
                            callback(true)
                        case .cancelled:
                            callback(false)
                        case .failure(_):
                            callback(false)
                        }
                }))
            case .cancelled:
                callback(false)
            case .failure(_):
                callback(false)
            }
        }))
    }
    
    // MARK: - Bluetooth Event
    
    fileprivate func handleEvent(_ event: Event, error: NSError?) {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot handle event: Bluejay is nil.")
        }
        
        bluejay.queue.process(event: event, error: error)
        updateOperations()
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
        
        // log.debug("Queueing read to: \(characteristicIdentifier.uuid.uuidString)")
        
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
                completion(.failure(Error.missingCharacteristic(characteristicIdentifier)))
            }
        })
    }
    
    /// Write to a specified characteristic.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (WriteResult) -> Void) {
        // log.debug("Queueing write to: \(characteristicIdentifier.uuid.uuidString) with value of: \(value)")
        
        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] success in
            guard let weakSelf = self else {
                return
            }
            
            // Not using the success variable here because the write operation will also catch the error if the service or the characteristic is not discovered.
            weakSelf.addOperation(
                WriteCharacteristic(characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, value: value, callback: completion))
        })
    }
    
    public func isListening(to characteristicIdentifier: CharacteristicIdentifier) -> Bool {
        return listeners.keys.contains(characteristicIdentifier)
    }
    
    /// Listen for notifications on a specified characterstic.
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
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
                    weakSelf.listeners[characteristicIdentifier] = { dataResult in
                        completion(ReadResult<R>(dataResult: dataResult))
                    }
                    
                    // Only bother caching if listen restoration is enabled.
                    if
                        let restoreIdentifier = weakSelf.bluejay?.restoreIdentifier,
                        weakSelf.bluejay?.listenRestorer != nil
                    {
                        // Make sure a successful listen is cached, so Bluejay can inform its delegate on which characteristics need their listens restored during state restoration.
                        weakSelf.cache(listeningCharacteristic: characteristicIdentifier, restoreIdentifier: restoreIdentifier)
                    }
                case .cancelled:
                    completion(.cancelled)
                case .failure(let error):
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
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, error: Swift.Error? = nil, completion: ((WriteResult) -> Void)? = nil) {
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
                    
                    if let error = error {
                        listenCallback?(.failure(error))
                    }
                    else {
                        listenCallback?(.cancelled)
                    }
                    
                    // Only bother removing the listen cache if listen restoration is enabled.
                    if
                        let restoreIdentifier = weakSelf.bluejay?.restoreIdentifier,
                        weakSelf.bluejay?.listenRestorer != nil
                    {
                        // Make sure an ended listen does not exist in the cache, as we don't want to restore a cancelled listen on state restoration.
                        weakSelf.remove(listeningCharacteristic: characteristicIdentifier, restoreIdentifier: restoreIdentifier)
                    }
                    
                    completion?(result)
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
    }
    
    // MARK: - Listen Caching
    
    private func cache(listeningCharacteristic: CharacteristicIdentifier, restoreIdentifier: RestoreIdentifier) {
        let serviceUUID = listeningCharacteristic.service.uuid.uuidString
        let characteristicUUID = listeningCharacteristic.uuid.uuidString
        
        let cacheData = NSKeyedArchiver.archivedData(
            withRootObject: ListenCache(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID).encoded!
        )
        
        // If the UserDefaults for the specified restore identifier doesn't exist yet, create one and add the ListenCache to it.
        guard
            let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches),
            let listenCacheData = listenCaches[restoreIdentifier] as? [Data]
        else
        {
            UserDefaults.standard.set([restoreIdentifier : [cacheData]], forKey: Constant.listenCaches)
            UserDefaults.standard.synchronize()
            
            return
        }
        
        // If the ListenCache already exists, don't add it to the cache again.
        if listenCacheData.contains(cacheData) {
            return
        }
        else {
            // Add the ListenCache to the existing UserDefaults for the specified restore identifier.
            var newListenCacheData = listenCacheData
            newListenCacheData.append(cacheData)
            
            var newListenCaches = listenCaches
            newListenCaches[restoreIdentifier] = newListenCacheData
            
            UserDefaults.standard.set(newListenCaches, forKey: Constant.listenCaches)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func remove(listeningCharacteristic: CharacteristicIdentifier, restoreIdentifier: RestoreIdentifier) {
        let serviceUUID = listeningCharacteristic.service.uuid.uuidString
        let characteristicUUID = listeningCharacteristic.uuid.uuidString
        
        guard
            let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches),
            let cacheData = listenCaches[restoreIdentifier] as? [Data]
        else {
            // Nothing to remove.
            return
        }
        
        var newCacheData = cacheData
        newCacheData = newCacheData.filter { (data) -> Bool in
            let listenCache = (NSKeyedUnarchiver.unarchiveObject(with: data) as? (ListenCache.Coding))!.decoded as! ListenCache
            return (listenCache.serviceUUID != serviceUUID) && (listenCache.characteristicUUID != characteristicUUID)
        }
        
        var newListenCaches = listenCaches
        
        // If the new cache data is empty after the filter removal, remove the entire cache entry for the specified restore identifier as well.
        if newCacheData.isEmpty {
            newListenCaches.removeValue(forKey: restoreIdentifier)
        }
        else {
            newListenCaches[restoreIdentifier] = newCacheData
        }
        
        UserDefaults.standard.set(newListenCaches, forKey: Constant.listenCaches)
        UserDefaults.standard.synchronize()
        
        listenersBeingCancelled = listenersBeingCancelled.filter { (characteristicIdentifier) -> Bool in
            return characteristicIdentifier.uuid.uuidString != listeningCharacteristic.uuid.uuidString
        }
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
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot handle did update value for \(characteristic.uuid.uuidString): Bluejay is nil.")
        }
        
        guard let listener = listeners[CharacteristicIdentifier(characteristic)] else {
            // Handle attempting to read a characteristic whose listen is being cancelled during state restoration.
            let isCancellingListenOnCurrentRead = listenersBeingCancelled.contains(where: { (characteristicIdentifier) -> Bool in
                return characteristicIdentifier.uuid.uuidString == characteristic.uuid.uuidString
            })
            
            let isReadUnhandled = isCancellingListenOnCurrentRead || (listeners.isEmpty && bluejay.queue.isEmpty())
            
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
