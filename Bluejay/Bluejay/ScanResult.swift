//
//  ScanResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-07.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Indicates a successful or failed scan attempt, where the success case contains a list of the peripherals scanned and their advertisement data.
public enum ScanResult {
    case success([(CBPeripheral, [String : Any])])
    case failure(Swift.Error)
}
