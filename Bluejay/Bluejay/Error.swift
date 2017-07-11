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
            userInfo: [NSLocalizedDescriptionKey: "Multiple scan is not supported."]
        )
    }
    
    static func multipleConnect() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Multiple connect is not supported."]
        )
    }
    
    static func multipleDisconnect() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Multiple disconnect is not supported."]
        )
    }
    
    static func connectionTimedOut() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Connection timed out."]
        )
    }
    
    static func notConnected() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Not connected to a peripheral."]
        )
    }
    
    static func missingService(_ service: ServiceIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Service not found: \(service.uuid)."]
        )
    }
    
    static func missingCharacteristic(_ char: CharacteristicIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Characteristic not found: \(char.uuid)."]
        )
    }
    
    static func cancelled() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled."]
        )
    }
    
    static func listenTimedOut() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 9,
            userInfo: [NSLocalizedDescriptionKey: "Listen timed out."]
        )
    }
    
    static func readFailed() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 10,
            userInfo: [NSLocalizedDescriptionKey: "Read failed."]
        )
    }
    
    static func writeFailed() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 11,
            userInfo: [NSLocalizedDescriptionKey: "Write failed."]
        )
    }
    
    static func missingData() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 12,
            userInfo: [NSLocalizedDescriptionKey: "No data from peripheral."]
        )
    }
        
    static func unexpectedPeripheral(_ peripheral: PeripheralIdentifier) -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 13,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected peripheral: \(peripheral.uuid)."]
        )
    }
    
    static func allowDuplicatesInBackground() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 14,
            userInfo: [NSLocalizedDescriptionKey: "Scanning with allow duplicates while in the background is not supported."]
        )
    }
    
    static func missingServiceIdentifiersInBackground() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 15,
            userInfo: [NSLocalizedDescriptionKey: "Scanning without specifying any service identifiers while in the background is not supported."]
        )
    }
    
    static func backgroundTaskRunning() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 16,
            userInfo: [NSLocalizedDescriptionKey: "Regular Bluetooth operation is not available when a background task is running. For reading, writing, and listening, please use only the API found in the Synchronized Peripheral provided to you when working inside a background task block."]
        )
    }
    
    static func multipleBackgroundTask() -> NSError {
        return NSError(
            domain: "Bluejay",
            code: 17,
            userInfo: [NSLocalizedDescriptionKey: "Multiple background task is not supported."]
        )
    }
    
}
