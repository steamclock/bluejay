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
    
    /// A cancelled error usually indicates that a read or write or listen operation has been cancelled programmatically.
    static func cancelledError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Operation cancelled."]
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
    
    /// A not connected error usually indicates that there is no connected peripheral for the attempted operation.
    static func notConnectedError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Peripheral is not connected."]
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
    
    /// A missing service error usually indicates that the requested Bluetooth Service cannot be found.
    static func missingServiceError(_ service: ServiceIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Service not found: \(service.uuid)"]
        )
    }
    
    /// A missing characteristic error usually indicates that the requested Bluetooth Characteristic cannot be found.
    static func missingCharacteristicError(_ char: CharacteristicIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Characteristic not found: \(char.uuid)"]
        )
    }
    
    static func timeoutError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Operation timed out."]
        )
    }
}
