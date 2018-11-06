//
//  Connection.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Types of connection time outs. Can specify a time out in seconds, or no time out.
public enum Timeout {
    /// Specify a timeout with a duration in seconds.
    case seconds(TimeInterval)
    /// Specify there is no timeout.
    case none
}

/// A connection operation.
class Connection: Queueable {

    /// The queue this operation belongs to.
    var queue: Queue?

    /// The state of this operation.
    var state: QueueableState

    /// The peripheral this operation is for.
    let peripheral: CBPeripheral

    /// The manager responsible for this operation.
    let manager: CBCentralManager

    /// Callback for the connection attempt.
    var callback: ((ConnectionResult) -> Void)?

    /// The warning options to use for this particular connection.
    let warningOptions: WarningOptions

    private var connectionTimer: Timer?
    private let timeout: Timeout?

    init(peripheral: CBPeripheral, manager: CBCentralManager, timeout: Timeout, warningOptions: WarningOptions, callback: @escaping (ConnectionResult) -> Void) {
        self.state = .notStarted

        self.peripheral = peripheral
        self.manager = manager
        self.timeout = timeout
        self.warningOptions = warningOptions
        self.callback = callback
    }

    deinit {
        log("Connection deinitialized.")
    }

    func start() {
        state = .running
        manager.connect(peripheral, options: warningOptions.dictionary)

        cancelTimer()

        if let timeOut = timeout, case let .seconds(timeoutInterval) = timeOut {
            if #available(iOS 10.0, *) {
                connectionTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false, block: { (_) in
                    self.timedOut()
                })
            } else {
                // Fallback on earlier versions
                connectionTimer = Timer.scheduledTimer(
                    timeInterval: timeoutInterval,
                    target: self,
                    selector: #selector(timedOut),
                    userInfo: nil,
                    repeats: false
                )
            }
        }

        log("Started connecting to \(peripheral.name ?? peripheral.identifier.uuidString).")
    }

    func process(event: Event) {
        if case .didConnectPeripheral(let peripheral) = event {
            success(peripheral)
        } else if case .didDisconnectPeripheral = event {
            if case .stopping(let error) = state {
                failed(error)
            } else if case .failed(let error) = state {
                failed(error)
            } else {
                preconditionFailure("Connection received a disconnected event but state was: \(state.description)")
            }
        } else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }

    func success(_ peripheral: Peripheral) {
        cancelTimer()

        state = .completed

        log("Connected to: \(peripheral.name).")

        callback?(.success(peripheral))
        callback = nil

        updateQueue()
    }

    func fail(_ error: Error) {
        cancelTimer()

        // There is no point trying to cancel the connection if the error is due to the manager being powered off, as trying to do so has no effect and will also cause CoreBluetooth to log an "API MISUSE" warning.
        if manager.state == .poweredOn {
            if case .running = state {
                log("Cancelling a pending connection to \(peripheral.name ?? peripheral.identifier.uuidString)")
                state = .stopping(error)
                manager.cancelPeripheralConnection(peripheral)
            } else {
                failed(error)
            }
        } else {
            failed(error)
        }
    }

    func failed(_ error: Error) {
        cancelTimer()

        var wasStopping = false
        if case .stopping(_) = state {
            wasStopping = true
        }

        state = .failed(error)

        if wasStopping {
            log("Pending connection cancelled with error: \(error.localizedDescription)")

            // Let Bluejay invoke the callback at the end of its disconnect clean up for more consistent ordering of callback invocation.

            updateQueue(cancel: true, cancelError: error)
        } else {
            log("Failed connecting to: \(peripheral.name ?? peripheral.identifier.uuidString) with error: \(error.localizedDescription)")

            callback?(.failure(error))
            callback = nil

            updateQueue()
        }
    }

    private func cancelTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }

    @objc private func timedOut() {
        fail(BluejayError.connectionTimedOut)
    }

}
