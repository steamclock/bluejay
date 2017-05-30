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

class Connection: Queueable {
    
    var queue: Queue?
    var state: QueueableState
    
    let peripheral: CBPeripheral
    let manager: CBCentralManager
    
    var callback: ((ConnectionResult) -> Void)?
    
    private var connectionTimer: Timer?
    private let timeoutInterval: TimeInterval = 15
    
    init(peripheral: CBPeripheral, manager: CBCentralManager, callback: @escaping (ConnectionResult) -> Void) {
        self.state = .notStarted
        
        self.peripheral = peripheral
        self.manager = manager
        
        self.callback = callback
    }
    
    func start() {
        state = .running
        manager.connect(peripheral, options: standardConnectOptions)
        
        cancelTimer()
        
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
        
        log("Started connecting to \(peripheral.name ?? peripheral.identifier.uuidString).")
    }
    
    func process(event: Event) {        
        if case .didConnectPeripheral(let peripheral) = event {
            success(peripheral)
        }
        else if case .didDisconnectPeripheral = event {
            cancelled()
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
        cancelTimer()
        
        if case .running = state {
            state = .cancelling
            manager.cancelPeripheralConnection(peripheral)
        }
        
        state = .cancelled
        
        log("Cancelled connection to: \(peripheral.name ?? peripheral.identifier.uuidString).")
        
        callback?(.cancelled)
        callback = nil
        
        updateQueue()
    }
    
    func fail(_ error: NSError) {
        cancelTimer()
        
        // There is no point trying to cancel the connection if the error is due to the manager being powered off, as trying to do so has no effect and will also cause CoreBluetooth to log an "API MISUSE" warning.
        if manager.state == .poweredOn {
            manager.cancelPeripheralConnection(peripheral)
        }
        
        state = .failed(error)
        
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
        fail(Error.connectionTimedOut())
    }
    
}
