//
//  Connection.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

var standardConnectOptions: [String : AnyObject] = [
    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true as AnyObject,
    CBConnectPeripheralOptionNotifyOnConnectionKey: true as AnyObject
]

/// Types of connection time outs. Can specify a time out in seconds, or no time out.
public enum Timeout {
    case seconds(TimeInterval)
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
    
    private var connectionTimer: Timer?
    private let timeout: Timeout?
    
    init(peripheral: CBPeripheral, manager: CBCentralManager, timeout: Timeout, callback: @escaping (ConnectionResult) -> Void) {
        self.state = .notStarted
        
        self.peripheral = peripheral
        self.manager = manager
        
        self.timeout = timeout
        
        self.callback = callback
    }
    
    func start() {
        state = .running
        manager.connect(peripheral, options: standardConnectOptions)
        
        cancelTimer()
        
        if let timeOut = timeout, case let .seconds(timeoutInterval) = timeOut  {
            if #available(iOS 10.0, *) {
                connectionTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false, block: { (timer) in
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
        }
        else if case .didDisconnectPeripheral = event {
            if case .failed(let error) = state {
                failed(error)
            }
            else {
                cancelled()
            }
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func success(_ peripheral: CBPeripheral) {
        cancelTimer()
        
        state = .completed
        
        log("Connected to: \(peripheral.name ?? peripheral.identifier.uuidString).")
        
        callback?(.success(peripheral))
        callback = nil
        
        updateQueue()
    }
    
    func cancel() {
        cancelTimer()
        
        if case .running = state {
            state = .cancelling
            manager.cancelPeripheralConnection(peripheral)
        }
        else {
            cancelled()
        }
    }
    
    func cancelled() {
        state = .cancelled
        
        log("Cancelled connection to: \(peripheral.name ?? peripheral.identifier.uuidString).")
        
        callback?(.cancelled)
        callback = nil
        
        updateQueue()
    }
    
    func fail(_ error: Error) {
        cancelTimer()
        
        state = .failed(error)
        
        // There is no point trying to cancel the connection if the error is due to the manager being powered off, as trying to do so has no effect and will also cause CoreBluetooth to log an "API MISUSE" warning.
        if manager.state == .poweredOn {
            // Don't cancel the existing connection if the error is caused by mistakingly adding another connection request while Bluejay is still connecting or connected.
            if case BluejayError.multipleConnectNotSupported = error {
                manager.cancelPeripheralConnection(peripheral)
            }
            else if case BluejayError.connectionTimedOut = error {
                manager.cancelPeripheralConnection(peripheral)
            }
            else {
                failed(error)
            }
        }
    }
    
    func failed(_ error: Error) {
        log("Failed connecting to: \(peripheral.name ?? peripheral.identifier.uuidString) with error: \(error.localizedDescription)")
        
        callback?(.failure(error))
        callback = nil
        
        updateQueue()
    }
    
    private func cancelTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    @objc private func timedOut() {
        fail(BluejayError.connectionTimedOut)
    }
    
}
