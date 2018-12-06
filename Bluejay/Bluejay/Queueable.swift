//
//  Queueable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-19.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

/**
 Defines the properties and behaviours of all Bluetooth operations that can be added to the Bluejay queue for ordered execution.
 */
protocol Queueable: class {

    var queue: Queue? { get set }

    /// The state of the operation in the queue.
    var state: QueueableState { get }

    /// Called when the queue would like to start the operation in question.
    func start()

    /// Called when the queue would like to notify the operation in question that there is a Bluetooth response.
    func process(event: Event)

    /// Called when the operation has failed.
    func fail(_ error: Error)

}

extension Queueable {

    func updateQueue(cancel: Bool = false, cancelError: Error? = nil) {
        guard let queue = queue else {
            preconditionFailure("Containing queue is nil.")
        }

        queue.update(cancel: cancel, cancelError: cancelError)
    }

}
