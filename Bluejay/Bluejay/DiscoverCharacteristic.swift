//
//  DiscoverCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

class DiscoverCharacteristic: Operation {

    var queue: Queue?
    var state: QueueableState

    var peripheral: CBPeripheral

    private var characteristicIdentifier: CharacteristicIdentifier
    private var callback: ((DiscoveryResult) -> Void)?

    init(characteristicIdentifier: CharacteristicIdentifier, peripheral: CBPeripheral, callback: @escaping (DiscoveryResult) -> Void) {
        self.state = .notStarted

        self.characteristicIdentifier = characteristicIdentifier
        self.peripheral = peripheral
        self.callback = callback
    }

    func start() {
        guard let service = peripheral.service(with: characteristicIdentifier.service.uuid) else {
            fail(BluejayError.missingService(characteristicIdentifier.service))
            return
        }

        if service.characteristic(with: characteristicIdentifier.uuid) != nil {
            success()
        } else {
            state = .running

            peripheral.discoverCharacteristics([characteristicIdentifier.uuid], for: service)
        }
    }

    func process(event: Event) {
        guard let service = peripheral.service(with: characteristicIdentifier.service.uuid) else {
            fail(BluejayError.missingService(characteristicIdentifier.service))
            return
        }

        if case .didDiscoverCharacteristics = event {
            if service.characteristic(with: characteristicIdentifier.uuid) == nil {
                fail(BluejayError.missingCharacteristic(characteristicIdentifier))
            } else {
                success()
            }
        } else {
            precondition(false, "Unexpected event response: \(event)")
        }
    }

    func success() {
        state = .completed

        callback?(.success)
        callback = nil

        updateQueue()
    }

    func fail(_ error: Error) {
        state = .failed(error)

        callback?(.failure(error))
        callback = nil

        updateQueue()
    }

}
