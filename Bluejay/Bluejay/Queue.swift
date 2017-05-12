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
    
    private weak var bluejay: Bluejay?
    
    private var scan: Scan?
    private var queue = [Queueable]()
    
    /// Helps distinguish one Queue instance from another.
    private var uuid = UUID()
    
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
            log("Starting queue with UUID: \(uuid.uuidString)")
            isCBCentralManagerReady = true
            update()
        }
    }
    
    func add(_ queueable: Queueable) {
        precondition(bluejay != nil, "Cannot enqueue: Bluejay instance is nil.")
        
        queueable.queue = self
        queue.append(queueable)
        
        update()
    }
    
    // MARK: - Cancellation
    
    @objc func cancelAll(_ error: NSError? = nil) {
        stopScanning(error)
        
        for queueable in queue where !queueable.state.isFinished {
            if let error = error {
                queueable.fail(error)
            }
            else {
                queueable.cancelled()
            }            
        }
        
        queue = []
    }
    
    func stopScanning(_ error: NSError? = nil) {
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
            log("Queue is empty, nothing to run.")
            return
        }
        
        if !isCBCentralManagerReady {
            log("Queue is paused because CBCentralManager is not ready yet.")
            return
        }
        
        if let queuable = queue.first {
            if queuable.state.isFinished {
                if queuable is Scan {
                    scan = nil
                }
                
                queue.removeFirst()
                update()
                
                return
            }
            
            if let bluejay = bluejay {
                if !bluejay.isBluetoothAvailable {
                    queuable.fail(Error.bluetoothUnavailable())
                }
                else if !bluejay.isConnected && !(queuable is Scan) {
                    queuable.fail(Error.notConnected())
                }
                else if case .notStarted = queuable.state {
                    queuable.start()
                }
            }
            else {
                preconditionFailure("Queue failure: Bluejay is nil.")
            }
        }
    }
    
    func process(event: Event, error: NSError?) {
        if isEmpty() {
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
    
    func isEmpty() -> Bool {
        return queue.isEmpty
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
                cancelAll(Error.bluetoothUnavailable())
            }
        }
    }
    
    func connected(_ peripheral: Peripheral) {
        update()
    }
    
}
