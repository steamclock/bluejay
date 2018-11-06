//
//  ReadCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A read operation.
class ReadCharacteristic<T: Receivable>: Operation {

    /// The queue this operation belongs to.
    var queue: Queue?

    /// The state of this operation.
    var state: QueueableState

    /// The peripheral this operation is for.
    var peripheral: CBPeripheral

    /// The characteristic to read from.
    private var characteristicIdentifier: CharacteristicIdentifier

    /// Callback for the read attempt.
    private var callback: ((ReadResult<T>) -> Void)?

    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, callback: @escaping (ReadResult<T>) -> Void) {
        self.state = .notStarted

        self.characteristicIdentifier = characteristicIdentifier
        self.peripheral = peripheral
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

        peripheral.readValue(for: characteristic)

        log("Started read for \(characteristicIdentifier.uuid) on \(peripheral.identifier).")
    }

    func process(event: Event) {
        if case .didReadCharacteristic(let readFrom, let value) = event {
            if readFrom.uuid != characteristicIdentifier.uuid {
                preconditionFailure("Expecting read from charactersitic: \(characteristicIdentifier.uuid), but actually read from: \(readFrom.uuid)")
            }

            state = .completed

            log("Read for \(characteristicIdentifier.uuid) on \(peripheral.identifier) is successful.")

            callback?(ReadResult<T>(dataResult: .success(value)))
            callback = nil

            updateQueue()
        } else {
            preconditionFailure("Expecting write to characteristic: \(characteristicIdentifier.uuid), but received event: \(event)")
        }
    }

    func fail(_ error: Error) {
        state = .failed(error)

        log("Failed reading for \(characteristicIdentifier.uuid) on \(peripheral.identifier) with error: \(error.localizedDescription)")

        callback?(.failure(error))
        callback = nil

        updateQueue()
    }

}
