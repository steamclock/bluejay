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
     * Called whenever the log file is updated.
     *
     * - Parameter logs: the full content of the log as a String.
     */
    func logFileUpdated(logs: String)
}

/// Allows creating weak references to LogObserver objects, so that Bluejay does not keep strong references to observers and prevent them from being released in memory.
struct WeakLogObserver {
    weak var weakReference: LogObserver?
}
