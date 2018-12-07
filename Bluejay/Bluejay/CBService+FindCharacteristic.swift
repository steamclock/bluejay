//
//  CBService+FindCharacteristic.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

extension CBService {

    /// Find a characteristic on a service by CBUUID.
    public func characteristic(with uuid: CBUUID) -> CBCharacteristic? {
        return characteristics?.first { $0.uuid == uuid }
    }

}
