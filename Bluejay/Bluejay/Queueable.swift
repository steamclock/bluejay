//
//  Queueable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-19.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
 Defines the properties and behaviours of all Bluetooth operations that can be added to the Bluejay queue for ordered execution.
 */
protocol Queueable: class {
    
    weak var queue: Queue? { get set }
    
    /// The state of the operation in the queue.
    var state: QueueableState { get }
    
    /// Called when the queue would like to start the operation in question.
    func start()
    
    /// Called when the queue would like to notify the operation in question that there is a Bluetooth response.
    func process(event: Event)
    
    /// Called when the operation in question should be cancelled for reasons that are not results of errors.
    func cancel()
    
    /// Called when the operation in question has finished cancelling.
    func cancelled()
    
    /// Called when the queue has determined that the operation in question has failed.
    func fail(_ error: Error)
    
}

extension Queueable {
    
    func updateQueue() {
        guard let queue = queue else {
            preconditionFailure("Containing queue is nil.")
        }
        
        queue.update()
    }
    
}
