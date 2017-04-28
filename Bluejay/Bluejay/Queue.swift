//
//  Queue.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

class Queue {
    
    static let shared = Queue()
    
    private var scan: Scan?
    private var connectionQueue = [Connection]()
    private var operationQueue = [Operation]()
    
    private var connectionTimer: Timer?
    
    @objc func cancelAll(_ error: NSError = Error.cancelledError()) {
        stopScanning(error)
        
        for connection in connectionQueue where !connection.state.isCompleted {
            connection.fail(error)
            update()
        }
        
        for operation in operationQueue where !operation.state.isCompleted {
            operation.fail(error)
            update()
        }
        
        connectionQueue = []
        operationQueue = []
    }
    
    func stopScanning(_ error: NSError) {
        scan?.fail(error)
        scan = nil
        
        update()
    }
    
    private func attemptScanning() {
        while scan != nil {
            switch scan!.state {
            case .notStarted:
                // log.debug("Scan is starting.")
                scan?.start()
            case .running:
                // log.debug("Scan is still running.")
                return
            case .failed(let error):
                // log.debug("Scan has failed.")
                stopScanning(error)
            case .completed:
                // log.debug("Scan has completed.")
                scan = nil
                update()
            }
        }
    }
    
    private func attemptConnections() {
        while connectionQueue.count > 0 {
            switch connectionQueue[0].state {
            case .notStarted:
                // log.debug("A task in the connection queue is starting.")
                
                stopConnectionTimer()
                startConnectionTimer()
                
                connectionQueue[0].start()
            case .running:
                // log.debug("A task in the connection queue is still running.")
                return
            case .failed(let error):
                // log.debug("A task in the connection queue has failed.")
                
                stopConnectionTimer()
                
                connectionQueue.removeFirst()
                cancelAll(error)
            case .completed:
                // log.debug("A task in the connection queue has completed.")
                
                stopConnectionTimer()
                
                connectionQueue.removeFirst()
                update()
            }
        }
    }
    
    private func startConnectionTimer() {
        // log.debug("Starting a connection timer.")
        
        if #available(iOS 10.0, *) {
            connectionTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false, block: { (timer) in
                // log.debug("A task in the connection queue has timed out.")
                self.cancelAll(Error.cancelledError())
            })
        } else {
            // Fallback on earlier versions
            connectionTimer = Timer.scheduledTimer(
                timeInterval: 15,
                target: self,
                selector: #selector(cancelAll(_:)),
                userInfo: nil,
                repeats: false
            )
        }
    }
    
    private func stopConnectionTimer() {
        // log.debug("Stopping a connection timer.")
        
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    private func attemptOperations() {
        while operationQueue.count > 0 {
            switch operationQueue[0].state {
            case .notStarted:
                // log.debug("A task in the operation queue is starting.")
                operationQueue[0].start()
            case .running:
                // log.debug("A task in the operation queue is still running.")
                return
            case .failed(let error):
                // log.debug("A task in the operation queue has failed.")
                operationQueue.removeFirst()
                cancelAll(error)
            case .completed:
                // log.debug("A task in the operation queue has completed.")
                operationQueue.removeFirst()
                update()
            }
        }
    }
    
    func update() {
        if !Bluejay.shared.isBluetoothAvailable {
            // log.debug("Queue is paused because Bluetooth is not available yet.")
            return
        }
        
        if scan == nil && connectionQueue.isEmpty && operationQueue.isEmpty {
            // log.debug("Queue is empty, nothing to run.")
            return
        }
        
        if scan != nil {
            // log.debug("Queue will handle a scan.")
            attemptScanning()
            return
        }
        
        if !connectionQueue.isEmpty {
            // log.debug("Queue will handle the connection queue.")
            attemptConnections()
            return
        }
        
        if !Bluejay.shared.isConnected {
            // log.debug("Queue is paused because no peripheral is connected.")
            return
        }
        
        // log.debug("Queue will handle the operation queue.")
        attemptOperations()
    }
    
    func add(scan: Scan) {
        // Cancel and reset the queue for the scan.
        cancelAll(Error.cancelledError())
        
        self.scan = scan
        update()
    }
    
    func add(connection: Connection) {
        connectionQueue.append(connection)
        update()
    }
    
    func add(operation: Operation) {
        operationQueue.append(operation)
        update()
    }
    
    func process(event: Event, error: NSError?) {
        precondition(scan != nil || connectionQueue.count > 0 || operationQueue.count > 0,
            "Tried to process an event when the queue is empty."
        )
        
        if error == nil {
            if scan != nil {
                scan?.process(event: event)
            }
            else if !connectionQueue.isEmpty {
                connectionQueue[0].process(event: event)
            }
            else if !operationQueue.isEmpty {
                operationQueue[0].process(event: event)
            }
            
            update()
        }
        else {
            cancelAll(error ?? Error.unknownError())
        }
    }
    
    func isEmpty() -> Bool {
        return scan == nil && connectionQueue.isEmpty && operationQueue.isEmpty
    }
    
    func isScanning() -> Bool {
        return scan != nil
    }
    
}

extension Queue: ConnectionObserver {
    
    func bluetoothAvailable(_ available: Bool) {
        if available {
            update()
        }
        else {
            if !isEmpty() {
                cancelAll(Error.unexpectedDisconnectError())
            }
        }
    }
    
    func connected(_ peripheral: Peripheral) {
        update()
    }
    
}
