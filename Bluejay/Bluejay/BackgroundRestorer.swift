//
//  BackgroundRestorer.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-11-16.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation
import UIKit

/**
 * Protocols for handling the results of a background restoration.
 *
 * - Important: The delegate must be an `UIApplicationDelegate` in order to properly support background restoration during `didFinishLaunchingWithOptions`.
 */
public protocol BackgroundRestorer: UIApplicationDelegate {
    /// Bluejay was able to restore a connection.
    func didRestoreConnection(to peripheral: PeripheralIdentifier) -> BackgroundRestoreCompletion
    /// Bluejay failed to restore a connection.
    func didFailToRestoreConnection(to peripheral: PeripheralIdentifier, error: Error) -> BackgroundRestoreCompletion
}

/**
 * Allows capturing further Bluejay operations to be queued and executed after background restoration is completed.
 */
public enum BackgroundRestoreCompletion {
    /// Put required Bluejay API or application calls that are needed after a background restoration inside this callback.
    case callback(() -> Void)
    /// Return this if no callback is needed after a background restoration.
    case `continue`
}
