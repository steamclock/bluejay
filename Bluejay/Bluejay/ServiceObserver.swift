//
//  ServiceObserver.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2019-02-21.
//  Copyright © 2019 Steamclock Software. All rights reserved.
//

import Foundation

/**
 A protocol allowing conforming objects to monitor the services changes of a connected peripheral.
 */
public protocol ServiceObserver: class {
    /**
     * Called whenever a peripheral's services change.
     *
     * - Parameters:
     *    - from: the peripheral that changed services.
     *    - invalidatedServices: the services invalidated.
     */
    func didModifyServices(from peripheral: PeripheralIdentifier, invalidatedServices: [ServiceIdentifier])
}

/// Allows creating weak references to ServiceObserver objects, so that Bluejay does not keep strong references to observers and prevent them from being released in memory.
struct WeakServiceObserver {
    weak var weakReference: ServiceObserver?
}
