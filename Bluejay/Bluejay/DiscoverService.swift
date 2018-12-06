//
//  DiscoverService.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-04.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

class DiscoverService: Operation {

    var queue: Queue?
    var state: QueueableState

    var peripheral: CBPeripheral

    private var serviceIdentifier: ServiceIdentifier
    private var callback: ((DiscoveryResult) -> Void)?

    init(serviceIdentifier: ServiceIdentifier, peripheral: CBPeripheral, callback: @escaping (DiscoveryResult) -> Void) {
        self.state = .notStarted

        self.serviceIdentifier = serviceIdentifier
        self.peripheral = peripheral
        self.callback = callback
    }

    func start() {
        if peripheral.service(with: serviceIdentifier.uuid) != nil {
            success()
        } else {
            state = .running

            peripheral.discoverServices([serviceIdentifier.uuid])
        }
    }

    func process(event: Event) {
        if case .didDiscoverServices = event {
            if peripheral.service(with: serviceIdentifier.uuid) == nil {
                fail(BluejayError.missingService(serviceIdentifier))
            } else {
                success()
            }
        } else {
            preconditionFailure("Unexpected event response: \(event)")
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
