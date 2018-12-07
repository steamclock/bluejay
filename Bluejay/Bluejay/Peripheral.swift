//
//  Peripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
 An interface to the Bluetooth peripheral.
 */
public class Peripheral: NSObject {

    // MARK: Properties

    private(set) weak var bluejay: Bluejay?
    private(set) var cbPeripheral: CBPeripheral

    private var listeners: [CharacteristicIdentifier: (ListenCallback?, MultipleListenOption)] = [:]
    private var observers: [WeakRSSIObserver] = []

    // MARK: - Initialization

    init(bluejay: Bluejay, cbPeripheral: CBPeripheral) {
        self.bluejay = bluejay
        self.cbPeripheral = cbPeripheral

        super.init()

        self.cbPeripheral.delegate = self

        log("Init Peripheral: \(self), \(self.cbPeripheral)")
    }

    deinit {
        log("Deinit Peripheral: \(self), \(cbPeripheral))")
    }

    // MARK: - Attributes

    /// The UUID of the peripheral.
    public var uuid: PeripheralIdentifier {
        return PeripheralIdentifier(uuid: cbPeripheral.identifier)
    }

    /// Returns the name of the peripheral. If name is not available, return the uuid string.
    public var name: String {
        return cbPeripheral.name ?? uuid.string
    }

    // MARK: - Operations

    private func updateOperations() {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot update operation: Bluejay is nil.")
        }

        if cbPeripheral.state == .disconnected {
            bluejay.cancelEverything(error: BluejayError.notConnected)
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
    private func discoverCharactersitic(_ characteristicIdentifier: CharacteristicIdentifier, callback: @escaping (DiscoveryResult) -> Void) {
        var discoverServiceFailed = false

        addOperation(DiscoverService(
            serviceIdentifier: characteristicIdentifier.service,
            peripheral: cbPeripheral,
            callback: { result in
            switch result {
            case .success:
                // Do nothing and wait for the subsequent discover characteristic operation to complete.
                break
            case .failure(let error):
                discoverServiceFailed = true
                callback(.failure(error))
            }
        }))

        addOperation(DiscoverCharacteristic(
            characteristicIdentifier: characteristicIdentifier,
            peripheral: cbPeripheral,
            callback: { result in
                if discoverServiceFailed {
                    return
                } else {
                    switch result {
                    case .success:
                        callback(.success)
                    case .failure(let error):
                        callback(.failure(error))
                    }
                }
        }))
    }

    // MARK: - Bluetooth Event

    private func handleEvent(_ event: Event, error: NSError?) {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot handle event: Bluejay is nil.")
        }

        bluejay.queue.process(event: event, error: error)
        updateOperations()
    }

    // MARK: - RSSI Event

    /// Requests the current RSSI value from the peripheral, and the value is returned via the `RSSIObserver` delegation.
    public func readRSSI() {
        cbPeripheral.readRSSI()
    }

    /// Register a RSSI observer that can receive the RSSI value when `readRSSI` is called.
    public func register(observer: RSSIObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
        observers.append(WeakRSSIObserver(weakReference: observer))
    }

    /// Unregister a RSSI observer.
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

        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] result in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success:
                weakSelf.addOperation(
                    ReadCharacteristic(characteristicIdentifier: characteristicIdentifier, peripheral: weakSelf.cbPeripheral, callback: completion)
                )
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    /// Write to a specified characteristic.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, type: CBCharacteristicWriteType = .withResponse, completion: @escaping (WriteResult) -> Void) {
        // log.debug("Queueing write to: \(characteristicIdentifier.uuid.uuidString) with value of: \(value)")

        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] result in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success:
                weakSelf.addOperation(
                    WriteCharacteristic(
                        characteristicIdentifier: characteristicIdentifier,
                        peripheral: weakSelf.cbPeripheral,
                        value: value,
                        type: type,
                        callback: completion)
                )
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    /// Checks whether Bluejay is currently listening to the specified charactersitic.
    public func isListening(to characteristicIdentifier: CharacteristicIdentifier) -> Bool {
        return listeners.keys.contains(characteristicIdentifier)
    }

    /// Listen for notifications on a specified characterstic.
    public func listen<R: Receivable>(
        to characteristicIdentifier: CharacteristicIdentifier,
        multipleListenOption option: MultipleListenOption,
        completion: @escaping (ReadResult<R>) -> Void) {

        // Fail this duplicate listen early if an original listen is being installed or installed and was configured to trap.
        guard listeners[characteristicIdentifier]?.1 != .trap else {
            completion(.failure(BluejayError.multipleListenTrapped))
            return
        }

        // Add to the listeners cache if it doesn't exist, but only option is saved and callback is nil because this first listen is not installed yet.
        if listeners[characteristicIdentifier] == nil {
            listeners[characteristicIdentifier] = (nil, option)
        } // If the listen already exists, don't overwrite its option.

        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] result in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success:
                weakSelf.addOperation(
                    ListenCharacteristic(
                        characteristicIdentifier: characteristicIdentifier,
                        peripheral: weakSelf.cbPeripheral,
                        value: true, callback: { result in
                            switch result {
                            case .success:
                                guard let cachedListener = weakSelf.listeners[characteristicIdentifier] else {
                                    fatalError("Installed a listen on characteristic \(characteristicIdentifier) but it is not cached.")
                                }

                                let originalMultipleListenOption = cachedListener.1

                                switch originalMultipleListenOption {
                                case .trap:
                                    precondition(cachedListener.0 == nil, "Duplicated listen installed despite original listen was set to trap.")
                                case .replaceable:
                                    if let previousListenerCallback = cachedListener.0 {
                                        previousListenerCallback(.failure(BluejayError.multipleListenReplaced))
                                    }
                                }

                                weakSelf.listeners[characteristicIdentifier] = ({ dataResult in
                                    completion(ReadResult<R>(dataResult: dataResult))
                                }, originalMultipleListenOption)

                                // Only bother caching if listen restoration is enabled.
                                if let restoreIdentifier = weakSelf.bluejay?.restoreIdentifier, weakSelf.bluejay?.listenRestorer != nil {
                                    do {
                                        // Make sure a successful listen is cached, so Bluejay can inform its delegate on which characteristics need their listens restored during state restoration.
                                        try weakSelf.cache(listeningCharacteristic: characteristicIdentifier, restoreIdentifier: restoreIdentifier)
                                    } catch {
                                        log("Failed to cache listen on characteristic: \(characteristicIdentifier.uuid) of service: \(characteristicIdentifier.service.uuid) for restore id: \(restoreIdentifier) with error: \(error.localizedDescription)")
                                    }
                                }
                            case .failure(let error):
                                weakSelf.listeners[characteristicIdentifier] = nil
                                completion(.failure(error))
                            }
                    }))
            case .failure(let error):
                weakSelf.listeners[characteristicIdentifier] = nil
                completion(.failure(error))
            }
        })
    }

    /**
     End listening on a specified characteristic.
     
     Provides the ability to suppress the failure message to the listen callback. This is useful in the internal implimentation of some of the listening logic, since we want to be able to share the clear logic on a .done exit, but don't need to send a failure in that case.
     
     - Note
     Currently this can also cancel a regular in-progress read as well, but that behaviour may change down the road.
     */
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, error: Error? = nil, completion: ((WriteResult) -> Void)? = nil) {
        listeners[characteristicIdentifier] = nil

        if let restoreIdentifier = bluejay?.restoreIdentifier {
            do {
                // Make sure an ended listen does not exist in the cache, as we don't want to restore a cancelled listen on state restoration.
                try remove(listeningCharacteristic: characteristicIdentifier, restoreIdentifier: restoreIdentifier)
            } catch {
                log("Failed to remove cached listen on characteristic: \(characteristicIdentifier.uuid) of service: \(characteristicIdentifier.service.uuid) for restore id: \(restoreIdentifier) with error: \(error.localizedDescription)")
            }
        }

        discoverCharactersitic(characteristicIdentifier, callback: { [weak self] result in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success:
                weakSelf.addOperation(
                    ListenCharacteristic(
                        characteristicIdentifier: characteristicIdentifier,
                        peripheral: weakSelf.cbPeripheral,
                        value: false,
                        callback: { result in
                            completion?(result)
                    })
                )
            case .failure(let error):
                completion?(.failure(error))
            }
        })
    }

    /// Restore a (believed to be) active listening session, so if we start up in response to a notification, we can receive it.
    public func restoreListen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        precondition(
            listeners[characteristicIdentifier] == nil,
            "Cannot have multiple active listens against the same characteristic"
        )

        listeners[characteristicIdentifier]?.0 = { dataResult in
            completion(ReadResult<R>(dataResult: dataResult))
        }
    }

    // MARK: - Listen Caching

    private func cache(listeningCharacteristic: CharacteristicIdentifier, restoreIdentifier: RestoreIdentifier) throws {
        let serviceUUID = listeningCharacteristic.service.uuid.uuidString
        let characteristicUUID = listeningCharacteristic.uuid.uuidString

        let encoder = JSONEncoder()

        do {
            let cacheData = try encoder.encode(ListenCache(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID))

            // If the UserDefaults for the specified restore identifier doesn't exist yet, create one and add the ListenCache to it.
            guard
                let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches),
                let listenCacheData = listenCaches[restoreIdentifier] as? [Data]
            else {
                UserDefaults.standard.set([restoreIdentifier: [cacheData]], forKey: Constant.listenCaches)
                UserDefaults.standard.synchronize()
                return
            }

            // If the ListenCache already exists, don't add it to the cache again.
            if listenCacheData.contains(cacheData) {
                return
            } else {
                // Add the ListenCache to the existing UserDefaults for the specified restore identifier.
                var newListenCacheData = listenCacheData
                newListenCacheData.append(cacheData)

                var newListenCaches = listenCaches
                newListenCaches[restoreIdentifier] = newListenCacheData

                UserDefaults.standard.set(newListenCaches, forKey: Constant.listenCaches)
                UserDefaults.standard.synchronize()
            }
        } catch {
            throw BluejayError.listenCacheEncoding(error)
        }
    }

    private func remove(listeningCharacteristic: CharacteristicIdentifier, restoreIdentifier: RestoreIdentifier) throws {
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
        let decoder = JSONDecoder()
        newCacheData = try newCacheData.filter { (data) -> Bool in
            do {
                let listenCache = try decoder.decode(ListenCache.self, from: data)
                return (listenCache.serviceUUID != serviceUUID) && (listenCache.characteristicUUID != characteristicUUID)
            } catch {
                throw BluejayError.listenCacheDecoding(error)
            }
        }

        var newListenCaches = listenCaches

        // If the new cache data is empty after the filter removal, remove the entire cache entry for the specified restore identifier as well.
        if newCacheData.isEmpty {
            newListenCaches.removeValue(forKey: restoreIdentifier)
        } else {
            newListenCaches[restoreIdentifier] = newCacheData
        }

        UserDefaults.standard.set(newListenCaches, forKey: Constant.listenCaches)
        UserDefaults.standard.synchronize()
    }

    /// Ask for the peripheral's maximum payload length in bytes for a single write request.
    public func maximumWriteValueLength(`for` writeType: CBCharacteristicWriteType) -> Int {
        return cbPeripheral.maximumWriteValueLength(for: writeType)
    }
}

// MARK: - CBPeripheralDelegate

extension Peripheral: CBPeripheralDelegate {

    /// Captures CoreBluetooth's did discover services event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        handleEvent(.didDiscoverServices, error: error as NSError?)
    }

    /// Captures CoreBluetooth's did discover characteristics event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        handleEvent(.didDiscoverCharacteristics, error: error as NSError?)
    }

    /// Captures CoreBluetooth's did write to charactersitic event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        handleEvent(.didWriteCharacteristic(characteristic), error: error as NSError?)
    }

    /// Captures CoreBluetooth's did receive a notification/value from a characteristic event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot handle did update value for \(characteristic.uuid.uuidString): Bluejay is nil.")
        }

        guard let listener = listeners[CharacteristicIdentifier(characteristic)], let listenCallback = listener.0 else {
            if bluejay.queue.isReading {
                handleEvent(.didReadCharacteristic(characteristic, characteristic.value ?? Data()), error: error as NSError?)
            } else if bluejay.queue.willEndListen(on: CharacteristicIdentifier(characteristic)) {
                log("Received read event with value \(String(data: characteristic.value ?? Data(), encoding: .utf8) ?? "") on characteristic \(characteristic.debugDescription), but queue contains an end listen operation for this characteristic.")
            } else {
                log("Unhandled read event with value \(String(data: characteristic.value ?? Data(), encoding: .utf8) ?? "") on characteristic \(characteristic.debugDescription)")
            }
            return
        }

        if let error = error {
            listenCallback(.failure(error))
        } else {
            listenCallback(.success(characteristic.value))
        }
    }

    /// Captures CoreBluetooth's did turn on or off notification/listening on a characteristic event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        handleEvent(.didUpdateCharacteristicNotificationState(characteristic), error: error as NSError?)
    }

    /// Captures CoreBluetooth's did read RSSI event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        for observer in observers {
            observer.weakReference?.peripheral(self, didReadRSSI: RSSI, error: error)
        }
    }

}
