//
//  Peripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/**
 An interface to the Bluetooth peripheral.
 */
class Peripheral: NSObject {

    // MARK: Properties

    private(set) weak var delegate: PeripheralDelegate!
    private(set) var cbPeripheral: CBPeripheral!

    private var listeners: [CharacteristicIdentifier: (ListenCallback?, MultipleListenOption)] = [:]

    // MARK: - Initialization

    init(delegate: PeripheralDelegate, cbPeripheral: CBPeripheral) {
        self.delegate = delegate
        self.cbPeripheral = cbPeripheral

        super.init()

        guard self.delegate != nil else {
            fatalError("Peripheral initialized without a PeripheralDelegate association.")
        }

        guard self.cbPeripheral != nil else {
            fatalError("Peripheral initialized without a CBPeripheral association.")
        }

        self.cbPeripheral.delegate = self

        debugLog("Init Peripheral: \(self), \(self.cbPeripheral.debugDescription)")
    }

    deinit {
        debugLog("Deinit Peripheral: \(self), \(self.cbPeripheral.debugDescription))")
    }

    // MARK: - Attributes

    /// The identifier for this peripheral.
    public var identifier: PeripheralIdentifier {
        return PeripheralIdentifier(uuid: cbPeripheral.identifier, name: cbPeripheral.name)
    }

    // MARK: - Operations

    private func addOperation(_ operation: Operation) {
        delegate.requested(operation: operation, from: self)
    }

    /// Queue the necessary operations needed to discover the specified characteristic.
    private func discoverCharactersitic(_ characteristicIdentifier: CharacteristicIdentifier, callback: @escaping (DiscoveryResult) -> Void) {
        var discoverServiceFailed = false

        addOperation(DiscoverService(
            serviceIdentifier: characteristicIdentifier.service,
            peripheral: cbPeripheral) { result in
            switch result {
            case .success:
                // Do nothing and wait for the subsequent discover characteristic operation to complete.
                break
            case .failure(let error):
                discoverServiceFailed = true
                callback(.failure(error))
            }
        })

        addOperation(DiscoverCharacteristic(
            characteristicIdentifier: characteristicIdentifier,
            peripheral: cbPeripheral) { result in
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
        })
    }

    // MARK: - Bluetooth Event

    private func handle(event: Event, error: NSError?) {
        delegate.received(event: event, error: error, from: self)
    }

    // MARK: - Actions

    /// Requests the current RSSI value from the peripheral.
    func readRSSI() {
        cbPeripheral.readRSSI()
    }

    /// Read from a specified characteristic.
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        precondition(
            listeners[characteristicIdentifier] == nil,
            "Cannot read from characteristic: \(characteristicIdentifier.description), which is already being listened on."
        )

        debugLog("Requesting read on \(characteristicIdentifier.description)...")

        discoverCharactersitic(characteristicIdentifier) { [weak self] result in
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
        }
    }

    /// Write to a specified characteristic.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, type: CBCharacteristicWriteType = .withResponse, completion: @escaping (WriteResult) -> Void) {

        debugLog("Requesting write on \(characteristicIdentifier.description)...")

        discoverCharactersitic(characteristicIdentifier) { [weak self] result in
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
        }
    }

    /// Checks whether Bluejay is currently listening to the specified charactersitic.
    public func isListening(to characteristicIdentifier: CharacteristicIdentifier) -> Bool {
        return listeners.keys.contains(characteristicIdentifier)
    }

    /// Listen for notifications on a specified characterstic.
    public func listen<R: Receivable>( // swiftlint:disable:this cyclomatic_complexity
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

        debugLog("Requesting listen on \(characteristicIdentifier.description)...")

        discoverCharactersitic(characteristicIdentifier) { [weak self] result in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success:
                weakSelf.addOperation(
                    ListenCharacteristic(
                        characteristicIdentifier: characteristicIdentifier,
                        peripheral: weakSelf.cbPeripheral,
                        value: true) { result in
                            switch result {
                            case .success:
                                guard let cachedListener = weakSelf.listeners[characteristicIdentifier] else {
                                    fatalError("Installed a listen on characteristic \(characteristicIdentifier.description) but it is not cached.")
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
                            case .failure(let error):
                                weakSelf.listeners[characteristicIdentifier] = nil
                                completion(.failure(error))
                            }
                    }
                )
            case .failure(let error):
                weakSelf.listeners[characteristicIdentifier] = nil
                completion(.failure(error))
            }
        }
    }

    /**
     End listening on a specified characteristic.

     Provides the ability to suppress the failure message to the listen callback. This is useful in the internal implimentation of some of the listening logic, since we want to be able to share the clear logic on a .done exit, but don't need to send a failure in that case.

     - Note
     Currently this can also cancel a regular in-progress read as well, but that behaviour may change down the road.
     */
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, error: Error? = nil, completion: ((WriteResult) -> Void)? = nil) {
        listeners[characteristicIdentifier] = nil

        debugLog("Requesting end listen on \(characteristicIdentifier.description)...")

        discoverCharactersitic(characteristicIdentifier) { [weak self] result in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success:
                weakSelf.addOperation(
                    ListenCharacteristic(
                        characteristicIdentifier: characteristicIdentifier,
                        peripheral: weakSelf.cbPeripheral,
                        value: false) { result in
                            completion?(result)
                    }
                )
            case .failure(let error):
                completion?(.failure(error))
            }
        }
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
        handle(event: .didDiscoverServices, error: error as NSError?)
    }

    /// Captures CoreBluetooth's did discover characteristics event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        handle(event: .didDiscoverCharacteristics, error: error as NSError?)
    }

    /// Captures CoreBluetooth's did write to charactersitic event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        handle(event: .didWriteCharacteristic(characteristic), error: error as NSError?)
    }

    /// Captures CoreBluetooth's did receive a notification/value from a characteristic event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let characteristicIdentifier = CharacteristicIdentifier(characteristic)

        guard let listener = listeners[characteristicIdentifier], let listenCallback = listener.0 else {
            if delegate.isReading(characteristic: characteristicIdentifier) {
                handle(event: .didReadCharacteristic(characteristic, characteristic.value ?? Data()), error: error as NSError?)
            } else if delegate.willEndListen(on: CharacteristicIdentifier(characteristic)) {
                debugLog("""
                    Received read event with value \(String(data: characteristic.value ?? Data(), encoding: .utf8) ?? "") \
                    on characteristic \(characteristic.debugDescription), \
                    but queue contains an end listen operation for this characteristic and should stop it soon.
                    """)
            } else {
                if delegate.backgroundRestorationEnabled() {
                    debugLog("""
                        Unhandled listen with value: \(String(data: characteristic.value ?? Data(), encoding: .utf8) ?? ""), \
                        on charactersitic: \(characteristic.debugDescription), \
                        from peripheral: \(identifier.description)
                        """)

                    delegate.receivedUnhandledListen(from: self, on: characteristicIdentifier, with: characteristic.value)
                } else {
                    debugLog("""
                        Unhandled read event value: \(String(data: characteristic.value ?? Data(), encoding: .utf8) ?? ""), \
                        on charactersitic: \(characteristic.debugDescription)
                        """)
                }
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
        handle(event: .didUpdateCharacteristicNotificationState(characteristic), error: error as NSError?)
    }

    /// Captures CoreBluetooth's did read RSSI event and pass it to Bluejay's queue for processing.
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        delegate.didReadRSSI(from: self, RSSI: RSSI, error: error)
    }

    /// Called when the peripheral removed or added services.
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        delegate.didModifyServices(
            from: self,
            invalidatedServices: invalidatedServices.map {
                ServiceIdentifier(uuid: $0.uuid)
            }
        )
    }

}
