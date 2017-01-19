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
    
    // Has priority over the peripheral's operations queue, so that any queued scan or connect requests can be handled first before attempting any peripheral operations.
    private var connections = [Connection]()
    
    private var operations = [Operation]()
    
    init() {
        Bluejay.shared.register(observer: self)
    }
    
    func cancelAll(_ error: NSError) {
        for connection in connections {
            connection.fail(error)
        }
        
        for operation in operations {
            operation.fail(error)
        }
        
        connections = []
        operations = []
    }
    
    func attemptConnections() {
        while connections.count > 0 {
            switch connections[0].state {
            case .notStarted:
                connections[0].start()
            case .running:
                return
            case .failed(let error):
                connections.removeFirst()
                cancelAll(error)
            case .completed:
                connections.removeFirst()
            }
        }
    }
    
    func update() {
        if !connections.isEmpty {
            log.debug("Operation queue is delayed in favour of handling the connection queue first.")
            attemptConnections()
            return
        }
        
        if !Bluejay.shared.isConnected {
            log.debug("Operation queue is paused because no peripheral is connected yet.")
            return
        }
        
        while operations.count > 0 {
            switch operations[0].state {
            case .notStarted:
                operations[0].start()
            case .running:
                return
            case .failed(let error):
                operations.removeFirst()
                cancelAll(error)
            case .completed:
                operations.removeFirst()
            }
        }
    }
    
    func add(connection: Connection) {
        connections.append(connection)
        update()
    }
    
    func add(operation: Operation) {
        operations.append(operation)
        update()
    }
    
    func process(event: Event, error: NSError?) {
        precondition(operations.count > 0, "Tried to process an operation when the queue has none.")
        
        if error == nil {
            connections.count != 0 ?
                connections[0].process(event: event) : operations[0].process(event: event)
            
            update()
        }
        else {
            cancelAll(error ?? Error.unknownError())
        }
    }
    
    func isEmpty() -> Bool {
        return operations.count == 0
    }
    
}

extension Queue: EventsObservable {
    
    func bluetoothAvailable(_ available: Bool) {
        if available {
            update()
        }
    }
    
    func connected(_ peripheral: Peripheral) {
        update()
    }
    
}
