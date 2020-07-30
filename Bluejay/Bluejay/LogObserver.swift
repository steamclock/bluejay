//
//  LogObserver.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2019-01-02.
//  Copyright © 2019 Steamclock Software. All rights reserved.
//

import Foundation

/**
 A protocol allowing conforming objects to monitor log file changes.
 */
public protocol LogObserver: class {
    /**
     * Called whenever a debug log message from the library is generated. Note, this callback may occur on an arbitrary thread, client is responsible for ensuring thread safety
     * of any code called from this.
     *
     * - Parameter text: the debug log text
     */
    func debug(_ text: String)
}

/// Allows creating weak references to LogObserver objects, so that Bluejay does not keep strong references to observers and prevent them from being released in memory.
struct WeakLogObserver {
    weak var weakReference: LogObserver?
}
