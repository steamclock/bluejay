//
//  Disconnection.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-10.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A disconnection operation.
class Disconnection: Queueable {

    /// The queue this operation belongs to.
    var queue: Queue?

    /// The state of this operation.
    var state: QueueableState

    /// The peripheral this operation is for.
    let peripheral: CBPeripheral

    /// The manager responsible for this operation.
    let manager: CBCentralManager

    /// Callback for the disconnection attempt.
    var callback: ((DisconnectionResult) -> Void)?

    init(peripheral: CBPeripheral, manager: CBCentralManager, callback: ((DisconnectionResult) -> Void)?) {
        self.state = .notStarted

        self.peripheral = peripheral
        self.manager = manager

        self.callback = callback
    }

    func start() {
        state = .running
        manager.cancelPeripheralConnection(peripheral)

        log("Started disconnecting from \(peripheral.name ?? peripheral.identifier.uuidString).")
    }

    deinit {
        log("Disconnection deinitialized.")
    }

    func process(event: Event) {
        if case .didDisconnectPeripheral(let peripheral) = event {
            success(peripheral)
        } else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }

    func success(_ peripheral: Peripheral) {
        state = .completed

        // Let Bluejay invoke the callback at the end of its disconnect clean up for more consistent ordering of callback invocation.

        updateQueue(cancel: true, cancelError: BluejayError.explicitDisconnect)
    }

    func fail(_ error: Error) {
        state = .failed(error)

        log("Failed disconnecting from: \(peripheral.name ?? peripheral.identifier.uuidString) with error: \(error.localizedDescription)")

        callback?(.failure(error))
        callback = nil

        updateQueue()
    }

}
