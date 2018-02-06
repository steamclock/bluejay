//
//  Error.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Errors specific to Bluejay.
public enum BluejayError {
    /// Bluetooth is either turned off or unavailable.
    case bluetoothUnavailable
    /// Bluejay does not support another scanning request if Bluejay is still scanning.
    case multipleScanNotSupported
    /// Bluejay does not support another connection request if Bluejay is already connected or still connecting.
    case multipleConnectNotSupported
    /// Bluejay does not support another disconnection request if Bluejay is still disconnecting.
    case multipleDisconnectNotSupported
    /// A connection request in Bluejay has timed out.
    case connectionTimedOut
    /// A Bluetooth operation such as, reading or writing, is attempted when Bluejay is not connected to a peripheral.
    case notConnected
    /// A Bluetooth service is not found.
    case missingService(ServiceIdentifier)
    /// A Bluetooth characteristic is not found.
    case missingCharacteristic(CharacteristicIdentifier)
    /// A Bluetooth operation is cancelled.
    case cancelled
    /// An attempt to listen on a characteristic has timed out.
    case listenTimedOut
    /// An attempt to read a characteristic has failed.
    case readFailed
    /// An attempt to write a characteristic has failed.
    case writeFailed
    /// An attempt to read a value from a characteristic has returned no data unexpectedly.
    case missingData
    /// An attempt to read a range of data has failed due to incorrect bounds or an unexpected length.
    case dataOutOfBounds(start: Int, length: Int, count: Int)
    /// An unexpected peripheral is cached and retrieved from CoreBluetooth.
    case unexpectedPeripheral(PeripheralIdentifier)
    /// iOS will not continue scanning in the background if allow duplicates is turned on.
    case scanningWithAllowDuplicatesInBackgroundNotSupported
    /// iOS will not continue scanning in the background if no service identifiers are specified.
    case missingServiceIdentifiersInBackground
    /// Bluejay does not support further Bluetooth operations while a Bluejay background task is still running.
    case backgroundTaskRunning
    /// Bluejay does not support another Bluejay background task when there is already one that is still running.
    case multipleBackgroundTaskNotSupported
    /// Bluejay has failed to encode a listen cache.
    case listenCacheEncoding(Error)
    /// Bluejay has failed to decode a listen cache.
    case listenCacheDecoding(Error)
    /// Bluejay has cancelled an expected end listen request.
    case endListenCancelled
}

extension BluejayError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth unavailable."
        case .multipleScanNotSupported:
            return "Multiple scan is not supported."
        case .multipleConnectNotSupported:
            return "Multiple connect is not supported."
        case .multipleDisconnectNotSupported:
            return "Multiple disconnect is not supported."
        case .connectionTimedOut:
            return "Connection timed out."
        case .notConnected:
            return "Not connected to a peripheral."
        case let .missingService(service):
            return "Service not found: \(service.uuid)."
        case let .missingCharacteristic(characteristic):
            return "Characteristic not found: \(characteristic.uuid)."
        case .cancelled:
            return "Cancelled"
        case .listenTimedOut:
            return "Listen timed out."
        case .readFailed:
            return "Read failed."
        case .writeFailed:
            return "Write failed."
        case .missingData:
            return "No data from peripheral."
        case let .dataOutOfBounds(start, length, count):
            return "Cannot extract data with a size of \(count) using start: \(start), length: \(length)."
        case let .unexpectedPeripheral(peripheral):
            return "Unexpected peripheral: \(peripheral.uuid)."
        case .scanningWithAllowDuplicatesInBackgroundNotSupported:
            return "Scanning with allow duplicates while in the background is not supported."
        case .missingServiceIdentifiersInBackground:
            return "Scanning without specifying any service identifiers while in the background is not supported."
        case .backgroundTaskRunning:
            return "Regular Bluetooth operation is not available when a background task is running. For reading, writing, and listening, please use only the API found in the Synchronized Peripheral provided to you when working inside a background task block."
        case .multipleBackgroundTaskNotSupported:
            return "Multiple background task is not supported."
        case let .listenCacheEncoding(error):
            return "Listen cache encoding failed with error: \(error.localizedDescription)"
        case let .listenCacheDecoding(error):
            return "Listen cache decoding failed with error: \(error.localizedDescription)"
        case .endListenCancelled:
            return "End listen cancelled."
        }
    }
}

extension BluejayError: CustomNSError {
    
    public static var errorDomain: String {
        return "Bluejay"
    }

    public var errorCode: Int {
        switch self {
        case .bluetoothUnavailable: return 1
        case .multipleScanNotSupported: return 2
        case .multipleConnectNotSupported: return 3
        case .multipleDisconnectNotSupported: return 4
        case .connectionTimedOut: return 5
        case .notConnected: return 6
        case .missingService: return 7
        case .missingCharacteristic: return 8
        case .cancelled: return 9
        case .listenTimedOut: return 10
        case .readFailed: return 11
        case .writeFailed: return 12
        case .missingData: return 13
        case .dataOutOfBounds: return 14
        case .unexpectedPeripheral: return 15
        case .scanningWithAllowDuplicatesInBackgroundNotSupported: return 16
        case .missingServiceIdentifiersInBackground: return 17
        case .backgroundTaskRunning: return 18
        case .multipleBackgroundTaskNotSupported: return 19
        case .listenCacheEncoding: return 20
        case .listenCacheDecoding: return 21
        case .endListenCancelled: return 22
        }
    }

    public var errorUserInfo: [String : Any] {
        guard let errorDescription = errorDescription else {
            return [:]
        }

        return [
            NSLocalizedDescriptionKey: errorDescription
        ]
    }
}
