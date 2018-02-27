//
//  Queue.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Allows the queue to notify states or delegate tasks.
protocol QueueObserver: class {
    /// Called when a queue is about to run a connection operation.
    func willConnect(to peripheral: CBPeripheral)
}

/// A queue for running Bluetooth operations in a FIFO order.
class Queue {
    
    /// Reference to the Bluejay that owns this queue.
    private weak var bluejay: Bluejay?
    
    /// Helps determine whether a scan is running or not.
    private var scan: Scan?
    
    /// The array of Bluetooth operations added.
    private var queue = [Queueable]()
    
    /// Helps distinguish one Queue instance from another.
    private var uuid = UUID()
    
    /// Helps determine whether CBCentralManager is being started up for the first time.
    private var isCBCentralManagerReady = false
        
    init(bluejay: Bluejay) {
        self.bluejay = bluejay
        log("Queue initialized with UUID: \(uuid.uuidString).")
    }
    
    deinit {
        log("Deinit Queue with UUID: \(uuid.uuidString).")
    }
    
    func start() {
        if !isCBCentralManagerReady {
            log("Starting queue with UUID: \(uuid.uuidString).")
            isCBCentralManagerReady = true
            update()
        }
    }
    
    func add(_ queueable: Queueable) {
        guard let bluejay = bluejay else {
            preconditionFailure("Cannot enqueue: Bluejay instance is nil.")
        }
        
        queueable.queue = self
        queue.append(queueable)
        
        /*
         Don't log the enqueuing of discovering services and discovering characteristics,
         as they are not exactly interesting and of importance in most cases.
         */
        if !(queueable is DiscoverService) && !(queueable is DiscoverCharacteristic) {
            // Log more readable details for enqueued ListenCharacteristic queueable.
            if queueable is ListenCharacteristic {
                let listen = (queueable as! ListenCharacteristic)
                
                let name = listen.value ? "Listen" : "End Listen"
                let char = listen.characteristicIdentifier.uuid.uuidString
                
                log("\(name) for \(char) added to queue with UUID: \(uuid.uuidString).")
            }
            else {
                log("\(queueable) added to queue with UUID: \(uuid.uuidString).")
            }
        }
        
        if queueable is Scan {
            if scan == nil {
                scan = queueable as? Scan
            }
            else {
                queueable.fail(BluejayError.multipleScanNotSupported)
            }
        }
        else if queueable is Connection {
            // Fail the connection request immediately if there is no disconnection queued and Bluejay is still connecting or connected.
            if !isDisconnectionQueued() && (bluejay.isConnecting || bluejay.isConnected) {
                queueable.fail(BluejayError.multipleConnectNotSupported)
                return
            }
            
            // Stop scanning when a connection is enqueued while a scan is still active, so that the queue can pop the scan task and proceed to the connection task without requiring the caller to explicitly stop the scan before making the connection request.
            if isScanning {
                stopScanning()
                return
            }
        }
        
        update()
    }
    
    private func isDisconnectionQueued() -> Bool {
        return queue.contains(where: { (queueable) -> Bool in
            return queueable is Disconnection
        })
    }
    
    // MARK: - Cancellation
    
    @objc func cancelAll(_ error: Error? = nil) {
        stopScanning(error)
        
        for queueable in queue where !queueable.state.isFinished {
            if let error = error {
                queueable.fail(error)
            }
            else {
                queueable.cancel()
            }            
        }
        
        queue = []
    }
    
    func stopScanning(_ error: Error? = nil) {
        if let error = error {
            scan?.fail(error)
        }
        else {
            scan?.cancel()
        }
        
        scan = nil
    }
    
    // MARK: - Queue
    
    func update() {
        if queue.isEmpty {
            // TODO: Minimize redundant calls to update, especially when queue is empty.
            // log("Queue is empty, nothing to run.")
            return
        }
        
        if !isCBCentralManagerReady {
            log("Queue is paused because CBCentralManager is not ready yet.")
            return
        }
        
        if let queueable = queue.first {
            // Remove current queueable if finished.
            if queueable.state.isFinished {
                if queueable is Scan {
                    scan = nil
                }
                
                queue.removeFirst()
                update()
                
                return
            }
            
            if let bluejay = bluejay {
                if !bluejay.isBluetoothAvailable {
                    // Fail any queuable if Bluetooth is not even available.
                    queueable.fail(BluejayError.bluetoothUnavailable)
                }
                else if !bluejay.isConnected && !(queueable is Scan) && !(queueable is Connection) {
                    // Fail any queueable that is not a Scan nor a Connection if no peripheral is connected.
                    queueable.fail(BluejayError.notConnected)
                }
                else if case .running = queueable.state {
                    // Do nothing if the current queueable is still running.
                    return
                }
                else if case .notStarted = queueable.state {
                    if let connection = queueable as? Connection {
                        bluejay.willConnect(to: connection.peripheral)
                    }
                    
                    queueable.start()
                }
            }
            else {
                preconditionFailure("Queue failure: Bluejay is nil.")
            }
        }
    }
    
    func process(event: Event, error: Error?) {
        if isEmpty {
            log("Queue is empty but received an event: \(event)")
            return
        }
        
        if let queueable = queue.first {
            if let error = error {
                queueable.fail(error)
            }
            else {
                queueable.process(event: event)
            }
        }
    }
    
    // MARK: - States
    
    var isEmpty: Bool {
        return queue.isEmpty
    }
    
    var isScanning: Bool {
        return scan != nil
    }
    
}

extension Queue: ConnectionObserver {
    
    func bluetoothAvailable(_ available: Bool) {
        if available {
            update()
        }
        else {
            if !isEmpty {
                cancelAll(BluejayError.bluetoothUnavailable)
            }
        }
    }
    
    func connected(_ peripheral: Peripheral) {
        update()
    }
    
}
