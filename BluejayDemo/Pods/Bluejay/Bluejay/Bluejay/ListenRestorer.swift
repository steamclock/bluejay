//
//  ListenRestorer.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-12.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
    A class protocol allowing notification of a characteristic being listened on, and provides an opportunity to restore its listen callback during Bluetooth state restoration.
 
    Bluetooth state restoration occurs when the background mode capability is turned on, and if the app is backgrounded or even terminated while a Bluetooth operation is still ongoing, iOS may keep the Bluetooth state alive, and attempt to restore it on resuming the app, so that the connection and operation between the app and the Bluetooth accessory is not interrupted and severed.
*/
public protocol ListenRestorer: class {
    /**
        Notify the conforming class that there is a characteristic being listened on, but it doesn't have any listen callbacks.
     
        - Note: Use the function `restoreListen` in Bluejay to restore the desired callback for the given characteristic and return true. Return false to prevent restoration, as well as to cancel the listening on the given characteristic.
     
        - Parameter on: the characterstic that is still being listened on when the CoreBluetooth stack is restored in the app.
        - Return: true if the characteristic's listen callback will be restored, false if the characteristic's listen should be cancelled and not restored.
    */
    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool
}

/// Allows creating a weak reference to a ListenRestorable object, so that the Bluejay instance does not prevent the deallocation of the delegate.
struct WeakListenRestorer {
    weak var weakReference: ListenRestorer?
}
