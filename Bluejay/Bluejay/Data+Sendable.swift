//
//  Data+Sendable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-03-09.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

extension Data: Sendable {
    
    public func toBluetoothData() -> Data {
        return self
    }
    
}
