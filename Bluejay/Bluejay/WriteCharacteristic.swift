//
//  WriteCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

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

    // Type of write
    var type: CBCharacteristicWriteType

    /// Callback for the write attempt.
    private var callback: ((WriteResult) -> Void)?

    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, value: T, type: CBCharacteristicWriteType = .withResponse, callback: @escaping (WriteResult) -> Void) {
        self.state = .notStarted

        self.characteristicIdentifier = characteristicIdentifier
        self.peripheral = peripheral
        self.value = value
        self.type = type
        self.callback = callback
    }

    func start() {
        guard
            let service = peripheral.service(with: characteristicIdentifier.service.uuid),
            let characteristic = service.characteristic(with: characteristicIdentifier.uuid)
        else {
            fail(BluejayError.missingCharacteristic(characteristicIdentifier))
            return
        }

        state = .running

        peripheral.writeValue(value.toBluetoothData(), for: characteristic, type: type)

        debugLog("Started write to \(characteristicIdentifier.description) on \(peripheral.identifier).")

        if type == .withoutResponse {
            process(event: .didWriteCharacteristic(characteristic))
        }
    }

    func process(event: Event) {
        if case .didWriteCharacteristic(let wroteTo) = event {
            if wroteTo.uuid != characteristicIdentifier.uuid {
                preconditionFailure("Expecting write to \(characteristicIdentifier.description), but actually wrote to \(wroteTo.uuid)")
            }

            state = .completed

            debugLog("Write to \(characteristicIdentifier.description) on \(peripheral.identifier) is successful.")

            callback?(.success)
            callback = nil

            updateQueue()
        } else {
            preconditionFailure("Expecting write to \(characteristicIdentifier.description), but received event: \(event)")
        }
    }

    func fail(_ error: Error) {
        state = .failed(error)

        debugLog("Failed writing to \(characteristicIdentifier.description) on \(peripheral.identifier) with error: \(error.localizedDescription)")

        callback?(.failure(error))
        callback = nil

        updateQueue()
    }

}
