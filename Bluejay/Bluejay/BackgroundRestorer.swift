//
//  BackgroundRestorer.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-11-16.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/// Make it clearer that the return type for the `BackgroundRestorer` protocols will be a completion block called at the end of a background restoration.
public typealias BackgroundRestoreCompletion = () -> Void

/// Protocols for handling the results of a background restoration.
public protocol BackgroundRestorer: class {
    /// Bluejay was able to restore a connection.
    func didRestoreConnection(to peripheral: Peripheral) -> BackgroundRestoreCompletion
    /// Bluejay failed to restore a connection.
    func didFailToRestoreConnection(to peripheral: Peripheral, error: Error) -> BackgroundRestoreCompletion
}
