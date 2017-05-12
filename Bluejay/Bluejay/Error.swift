//
//  Error.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
    A struct for generating Bluejay-specific errors.
 */
struct Error {
    
    static func bluetoothUnavailable() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Bluetooth unavailable."]
        )
    }
    
    static func multipleScan() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Multiple scan is not allowed."]
        )
    }
    
    static func multipleConnect() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Multiple connect is not allowed."]
        )
    }
    
    static func connectionTimedOut() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Connection timed out."]
        )
    }
    
    static func notConnected() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Not connected to a peripheral."]
        )
    }
    
    static func missingService(_ service: ServiceIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Service not found: \(service.uuid)."]
        )
    }
    
    static func missingCharacteristic(_ char: CharacteristicIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Characteristic not found: \(char.uuid)."]
        )
    }
    
    static func cancelled() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled."]
        )
    }
    
    static func listenTimedOut() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Listen timed out."]
        )
    }
        
    /// An unknown error should almost never happen, and if it does occur, it usually means there's something seriously wrong in either the internal implementation or the external usage of Bluejay.
    static func unknownError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error."]
        )
    }
    
    /// A missing data error usually indicates that an attempt to read some data off of a peripheral has yielded no data at all.
    static func missingDataError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No data from peripheral."]
        )
    }
        
    /// An unknown peripheral error usually indicates that the peripheral about to be worked with is not the expected peripheral.
    static func unknownPeripheralError(_ peripheral: PeripheralIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Unknown peripheral: \(peripheral.uuid)"]
        )
    }
        
    /// An unexpected disconnection error usually indicates that a connection to a peripheral has been forcefully disconnected either purposely or unpurposely.
    static func unexpectedDisconnectError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected peripheral disconnection."]
        )
    }
    
}
