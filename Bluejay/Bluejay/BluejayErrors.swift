//
//  BluejayErrors.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

struct BluejayErrors {
    
    static func unknownError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error."]
        )
    }
    
    static func missingDataError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No data from peripheral."]
        )
    }
    
    static func cancelledError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Operation cancelled."]
        )
    }
    
    static func unknownPeripheralError(_ peripheral: PeripheralIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Unknown peripheral: \(peripheral.uuid)"]
        )
    }
    
    static func notConnectedError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Peripheral is not connected."]
        )
    }
    
    static func unexpectedDisconnectError() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected peripheral disconnection."]
        )
    }
    
    static func missingServiceError(_ service: ServiceIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Service not found: \(service.uuid)"]
        )
    }
    
    static func missingCharacteristicError(_ char: CharacteristicIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Characteristic not found: \(char.uuid)"]
        )
    }
    
}
