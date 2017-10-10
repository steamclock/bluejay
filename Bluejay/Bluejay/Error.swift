//
//  Error.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

public enum BluejayError {
    case bluetoothUnavailable
    case multipleScanNotSupported
    case multipleConnectNotSupported
    case multipleDisconnectNotSupported
    case connectionTimedOut
    case notConnected
    case missingService(ServiceIdentifier)
    case missingCharacteristic(CharacteristicIdentifier)
    case cancelled
    case listenTimedOut
    case readFailed
    case writeFailed
    case missingData
    case dataOutOfBounds(start: Int, length: Int, count: Int)
    case unexpectedPeripheral(PeripheralIdentifier)
    case scanningWithAllowDuplicatesInBackgroundNotSupported
    case missingServiceIdentifiersInBackground
    case backgroundTaskRunning
    case multipleBackgroundTaskNotSupported
    case listenCacheEncoding(Error)
    case listenCacheDecoding(Error)
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
