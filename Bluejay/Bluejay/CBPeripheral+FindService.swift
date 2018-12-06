//
//  CBPeripheral+FindService.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

extension CBPeripheral {

    /// Find a service on a peripheral by CBUUID.
    public func service(with uuid: CBUUID) -> CBService? {
        return services?.first { $0.uuid == uuid }
    }

}
