//
//  ListenRestorer.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-13.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation
import UIKit

/**
 * Protocol for handling a listen event that does not have a callback due to background restoration.
 */
public protocol ListenRestorer: UIApplicationDelegate {

    /**
     * Called whenever there is an unhandled listen.
     *
     * - Parameters:
     *    - from: the peripheral receiving the unhandled listen notification.
     *    - on: the notifying characteristic.
     *    - with: the notified value.
     */
    func didReceiveUnhandledListen(
        from peripheral: PeripheralIdentifier,
        on characteristic: CharacteristicIdentifier,
        with value: Data?) -> ListenRestoreAction
}

/**
 * Available actions to take on an unhandled listen event from background restoration.
 */
public enum ListenRestoreAction {
    /// Bluejay will continue to receive but do nothing with the incoming listen events until a new listener is installed.
    case promiseRestoration
    /// Bluejay will attempt to turn off notifications on the peripheral.
    case stopListen
}
